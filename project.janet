(declare-project
  :name "art-cendyne"
  :description "Art"
  :author "Cendyne"
  :url "https://github.com/cendyne/art.cendyne.dev"
  :repo "git+https://github.com/cendyne/art.cendyne.dev"
  :dependencies [
    "https://github.com/joy-framework/joy"
    "https://github.com/janet-lang/sqlite3"
    "https://github.com/levischuck/janetls"
    {:repo "https://github.com/cendyne/simple-janet-crypto" :tag "main"}
    ]
  )

(phony "server" []
  (if (= "development" (os/getenv "JOY_ENV"))
      # TODO check if entr exists
    (os/shell "find . -name '*.janet' | entr janet main.janet")
    (os/shell "janet src/main.janet")))

(declare-executable
  :name "art"
  :entry "src/main.janet"
  )

