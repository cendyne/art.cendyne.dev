(use joy)
(import ./auth)
(import ./body-parser)
(import ./initialize)
(import ./json-response)

(import ./routes/index)


(route :get "/" index/index :index/index)
(route :get "/tags" index/tags :index/tags)
(route :get "/random" index/random :index/random)
(route :put "/art" index/put-art :index/put-art)
(route :get "/art/:id" index/get-art :index/get-art)

(def app (-> (handler)
             (json-response/with-json-body)
             (auth/authorization)
             (extra-methods)
             (query-string)
             (body-parser/json)
             (server-error)
             (x-headers)
             (static-files)
             (not-found)
             (logger)))

(defn main [& args]
  # Stuff must be available for the runtime within main
  (initialize/initialize)
  (let [port (get args 1 (or (env :port) "9001"))
        host (get args 2 (or (env :host) "localhost"))]
    (server app port host)))