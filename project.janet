(declare-project
  :name "janet-agent"
  :author "Gemini"
  :license "MIT"
  :description "A simple tool to deploy agents files."
  :source ["src/main.janet"]
  :entry "main.janet")

(declare-executable
  :name "janet-agent"
  :entry "src/main.janet")
