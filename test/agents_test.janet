(import path)

(def repo-root (path/abspath (os/cwd)))
(def agent (dofile (path/join repo-root "src/agent.janet")))
(def exports ((agent 'exported) :value))

(def fails @[])
(defn ok [msg] (print (string "[OK] " msg)))
(defn fail [msg]
  (eprint (string "[FAIL] " msg))
  (array/push fails msg))
(defn assert [pred msg]
  (if pred (ok msg) (fail msg)))
(defn assert-eq [a b msg]
  (assert (= a b) (string msg " | expected=" b " got=" a)))

(defn write-file [p content]
  (os/shell (string "mkdir -p " (path/dirname p)))
  (with [f (file/open p :w)] (file/write f content)))

(defn read-file [p]
  (string (slurp p)))

(defn sh [cmd &opt cwd]
  (let [envprefix (if cwd (string "HOME='" cwd "' GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null ") "")
        full (if cwd (string "(cd '" cwd "' && " envprefix cmd ")") cmd)
        res (os/shell full)]
    (when (not= 0 (res :exit))
      (error (string "cmd failed: " cmd "\n" (res :err))))
    res))

# Test: pack and restore agents.md tracked by git
(def tmp (path/abspath (path/join repo-root "tmp-agents/test-pack-restore")))
(os/shell (string "rm -rf '" tmp "'"))
(os/shell (string "mkdir -p '" tmp "'"))

# Create files
(def files ["AGENTS.md" "sub/Agents.md" "deep/nest/agents.MD" "other/notagents.txt"])
(each f files (write-file (path/join tmp f) (string "content-" f)))

# Work in the temp directory (no git repo, triggers fallback scan)
(os/cd tmp)

(let [found ((exports :find-agents))]
  (assert-eq (length found) 3 "found three agents.md")
  (assert (some |(= $ "AGENTS.md") found) "found AGENTS.md at root")
  (assert (some |(= $ "sub/Agents.md") found) "found sub/Agents.md")
  (assert (some |(= $ "deep/nest/agents.MD") found) "found deep/nest/agents.MD"))

(def zip ((exports :pack-agents)))
(assert-eq zip "agents.zip" "pack returned default zip name")
(assert (os/stat (path/join tmp zip)) "zip file exists")

(def originals (tabseq [p :in ((exports :find-agents))] [p (read-file p)]))
(each p (keys originals) (write-file p "BAD"))

((exports :restore-agents))
(each [p v] originals (assert-eq (read-file p) v (string "restored content for " p)))

# Scenario 2: respect .gitignore directories at multiple levels
(def tmp2 (path/abspath (path/join repo-root "tmp-agents/test-ignore")))
(os/shell (string "rm -rf '" tmp2 "'"))
(os/shell (string "mkdir -p '" tmp2 "'"))
(os/cd tmp2)

# .gitignore at root ignoring skipme/ and deep/ignored/
(write-file ".gitignore" "skipme/\ndeep/ignored/\n")

# Ignored files
(write-file "skipme/agents.md" "ignored-1")
(write-file "deep/ignored/agents.md" "ignored-2")

# Not ignored
(write-file "deep/ok/agents.md" "kept")
(write-file "root/Agents.md" "kept2")

(let [found ((exports :find-agents))]
  (assert (not (some |(string/find $ "skipme/") found)) "ignored skipme/ directory")
  (assert (not (some |(string/find $ "deep/ignored/") found)) "ignored deep/ignored/ directory")
  (assert (some |(= $ "deep/ok/agents.md") found) "kept deep/ok/agents.md")
  (assert (some |(= $ "root/Agents.md") found) "kept root/Agents.md"))

(when (> (length fails) 0)
  (eprint (string "Failures: " (length fails)))
  (os/exit 1))
