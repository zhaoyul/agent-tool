## agent.janet - pack and restore agents.md files

(import path)

(defn- shell-escape [s]
  # Minimal POSIX shell escaping using single quotes
  (string "'" (string/replace "'" "'\\''" s) "'"))

(defn- is-dir? [p]
  (let [st (os/stat p)]
    (and st (= (st :mode) :directory))))

(defn- run [cmd]
  (let [code (os/shell cmd)]
    (when (not= 0 code)
      (error (string "Command failed (" code "): " cmd)))
    code))

(defn find-agents
  "Scan the working directory for files named agents.md (case-insensitive), ignoring .git."
  []
  (def found @[])
  (defn walk [dir]
    (when (and (os/stat dir) (is-dir? dir))
      (when (not= ".git" (path/basename dir))
        (each f (os/dir dir)
          (def p (path/join dir f))
          (cond
            (is-dir? p) (walk p)
            (and (os/stat p)
                 (= "agents.md" (string/ascii-lower (path/basename p))))
              (array/push found (string/replace "./" "" p))
            :else nil)))))
  (walk ".")
  found)

(defn pack-agents
  "Create agents.zip containing all agents.md files with their relative paths."
  [&opt zip-path]
  (def zip-file (or zip-path "agents.zip"))
  (def files (find-agents))
  (when (empty? files)
    (print "No agents.md files found.")
    (return :none))
  # Remove existing zip if present so result is deterministic
  (os/shell (string "rm -f " (shell-escape zip-file)))
  # Build zip command with all files
  (def args (string/join (map shell-escape files) " "))
  (run (string "zip -q -X " (shell-escape zip-file) " " args))
  (print (string "Packed " (length files) " file(s) into " zip-file))
  zip-file)

(defn restore-agents
  "Restore agents.md files from agents.zip back to original paths."
  [&opt zip-path]
  (def zip-file (or zip-path "agents.zip"))
  (when (nil? (os/stat zip-file))
    (error (string "Zip not found: " zip-file)))
  (run (string "unzip -o -q " (shell-escape zip-file)))
  (print (string "Restored files from " zip-file))
  true)

(def exported {:find-agents find-agents :pack-agents pack-agents :restore-agents restore-agents})
exported
