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

(defn- starts-with [s prefix]
  (and (<= (length prefix) (length s))
       (= (string/slice s 0 (length prefix)) prefix)))

(defn- read-gitignore-dirs [dir]
  # Return absolute (relative to cwd) normalized directory paths to ignore from .gitignore in dir.
  (def ignores @[])
  (def gi (path/join dir ".gitignore"))
  (when (and (os/stat gi) (not (is-dir? gi)))
    (def content (string (slurp gi)))
    (each line (string/split "\n" content)
      (def l (string/trim line))
      (when (and (not (empty? l))
                 (not (= (string/slice l 0 1) "#"))
                 (not (= (string/slice l 0 1) "!")))
        (when (= (string/slice l (- (length l) 1)) "/")
          (def entry (string/slice l 0 (- (length l) 1)))
          (when (not (empty? entry))
            (def full (path/normalize (path/join dir entry)))
            (array/push ignores full))))))
  ignores)

(defn- under-ignored? [p ignores]
  (def pnorm (path/normalize p))
  (def sep path/sep)
  (or
    (some (fn [ig]
            (or (= pnorm ig)
                (starts-with pnorm (string ig sep))))
          ignores)
    false))

(defn find-agents
  "Find agents.md files.
  - If在 git 仓库内: 使用 `git ls-files --cached --others --exclude-standard` 列出受控与未受控(未忽略)文件，然后按文件名过滤。
  - 否则: 回退到目录扫描，并按 .gitignore 中的目录条目进行忽略。"
  []
  (var gfiles nil)
  (when (= 0 (os/shell "git rev-parse --is-inside-work-tree >/dev/null 2>&1"))
    (def tmp "build/.agents-ls-files")
    (os/shell "mkdir -p build")
    (def cmd (string "git ls-files --cached --others --exclude-standard > '" tmp "'"))
    (when (= 0 (os/shell cmd))
      (def content (string (slurp tmp)))
      (os/shell (string "rm -f '" tmp "'"))
      (def out @[])
      (each p (string/split "\n" content)
        (when (and (not (empty? p))
                   (= "agents.md" (string/ascii-lower (path/basename p))))
          (array/push out p)))
      (set gfiles out)))
  (if gfiles
    gfiles
    (do
      # Fallback to scan + .gitignore directory rules
      (def found @[])
      (defn walk [dir inherited-ignores]
        (when (and (os/stat dir) (is-dir? dir))
          (when (not= ".git" (path/basename dir))
            (def ignores @[])
            (each x inherited-ignores (array/push ignores x))
            (each x (read-gitignore-dirs dir) (array/push ignores x))
            (each f (os/dir dir)
              (def p (path/join dir f))
              (when (not (under-ignored? p ignores))
                (if (is-dir? p)
                  (walk p ignores)
                  (when (= "agents.md" (string/ascii-lower (path/basename p)))
                    (array/push found (string/replace "./" "" p)))))))))
      (walk "." @[])
      found)))

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
