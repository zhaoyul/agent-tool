(import ./agent :as agent)

(defn usage []
  (print "Usage: janet src/main.janet [pack|restore] [zipfile]")
  (print "  pack    -> create agents.zip (or specified zip)")
  (print "  restore -> extract agents.zip back to original paths"))

(defn main [& args]
  (match args
    ["pack"] (agent/pack-agents)
    ["pack" zip] (agent/pack-agents zip)
    ["restore"] (agent/restore-agents)
    ["restore" zip] (agent/restore-agents zip)
    _ (usage)))
