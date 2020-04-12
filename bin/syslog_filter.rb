#!/usr/bin/env ruby
require 'json'
require 'concurrent'

cfg = JSON.parse(File.read("#{File.dirname(File.expand_path(__FILE__))}/syslog_filter.cfg"))

TAG_EVENT   = JSON.parse(File.read(cfg['tag_event_file'])) # file che contiene l'associazione tra tag e descrizione dell'evento
OUTPUT_FILE = cfg['output_file'] # file in cui scrivere l'output ogni i_value secondi
WINDOW_SIZE = cfg['window_size'].to_i # dimensioni della finestra temporale di analisi
OUTPUT_FREQ = cfg['csv_write_freq'].to_i # ogni quanto aggiornare i risultati
NODE_LIST   = cfg['node_list'].split(',') # lista di nodi da cui vengono generati i log

buffer = Concurrent::Array.new # buffer degli eventi ricevuti
# inizializzo l'hash dei risultati {IP1 => { TAG1 => 0, TAG2 => 0, ...}, IP2 => {...} }
results_hash = Concurrent::Hash.new 
NODE_LIST.each do |ip|
	results_hash[ip] = Concurrent::Hash.new
	TAG_EVENT.each_key do |key| 
		results_hash[ip][key] = 0
	end                           
end

# Thread di scrittura su file
Concurrent::TimerTask.new(execution_interval: OUTPUT_FREQ) do # periodicamente, con frequenza OUTPUT_FREQ:
	csv_text = "Evento;Numero Occorrenze;Nodo\n" # preparo l'intestazione del csv e poi aggiungo il contenuto
	NODE_LIST.each do |host|
		results_hash[host].each_key do |tag| 
			csv_text << "#{TAG_EVENT[tag]};#{results_hash[host][tag]};#{host}\n"
		end
	end
	
	begin
		File.write(OUTPUT_FILE, csv_text) # scrivo il csv su file
	rescue
		abort('Impossibile scrivere sul file di output. Controllare i permessi e riprovare')
	end
end.execute

# Thread gestione buffer/sliding window  
Concurrent::ScheduledTask.execute(WINDOW_SIZE) do # la gestione della sliding window inizia quando viene raggiunta l'ampiezza
	Concurrent::TimerTask.new(execution_interval: 1) do # ogni secondo, inizia il processo di manutenzione del buffer:
		now = Time.now.to_i # l'istante in unix timestamp
		buffer.each do |log| # per ogni valore nel buffer
			if (log['date'] + WINDOW_SIZE < now) # se il log non e` piu` nella finestra temporale...
				results_hash[log['host']][log['tags']] -= 1 # ...decremento il contatore che gli corrisponde nella tabella dei valori
			end
		end
		buffer.delete_if {|log| log['date'] + WINDOW_SIZE < now } # elimino tutti i valori fuori dalla finestra temporale
	end.execute
end

# Thread principale
while recv_log = gets # ricevo i log da STDIN
	log = JSON.parse(recv_log) # parso i log in formato JSON
	if NODE_LIST.include? log['host'] # se l'host e` nella whitelist
		log['tags'].split(',').each do |tag| # controllo quale dei tag e` stato riconosciuto
			if TAG_EVENT.keys.include? tag # se lo riconosco
				log['tags'] = tag # sostituisco la lista di tag con un solo tag. Questo rendera` le cose piu` semplici nelle operazioni sulla tabella dei valori
				log['date'] = log['date'].to_i # il timestamp e` ricevuto come stringa, ma verra` usato come intero
				buffer << log # aggiungo il valore al buffer
				results_hash[log['host']][log['tags']] += 1 # incremento il valore nella tabella dei valori
			end
		end
	end
end
