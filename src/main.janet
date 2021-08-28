(use janetls)
(use joy)
(import ./middleware)
(import ./initialize)
(import ./session)
(import ./secrets)

(import ./routes/index)
(import ./routes/authenticate)
(import ./routes/gallery)
(import ./routes/api)


(route :get "/" index/index :index/index)

(route :get "/api/tags" api/tags :api/tags)
(route :get "/api/random" api/random :api/random)
(route :put "/api/art" api/put-art :api/put-art)
(route :get "/api/art/:id" api/get-art :api/get-art)
(route :put "/api/upload" api/upload :api/upload)
(route :get "/api/negotiate/:id" api/negotiate :api/negotiate)
(route :get "/api/unlinked-files" api/unlinked-files :api/unlinked-files)
(route :get "/api/unmanaged-files" api/unmanaged-files :api/unmanaged-files)
(route :delete "/api/files" api/delete-files :api/delete-files)
(route :delete "/api/art/:id" api/delete-art :api/delete-art)

(route :get "/view/:id" gallery/view :gallery/view)
(route :get "/gallery" gallery/index :gallery/index)

(route :get "/authenticate" authenticate/index :authenticate/index)
(route :post "/authenticate" authenticate/post-form :authenticate/post-form)
(route :post "/unauthenticate" authenticate/unauthenticate :authenticate/unauthenticate)

(def app (-> (handler)
             (middleware/authorization)
             (extra-methods)
             (query-string)
             (middleware/www-url-form)
             (middleware/json)
             (session/with-session (secrets/session-key))
             (server-error)
             (middleware/static-files)
             (not-found)
             (logger)
             ))

(defn main [& args]
  # Stuff must be available for the runtime within main
  (initialize/initialize)
  (let [port (get args 1 (or (env :port) "9000"))
        host (get args 2 (or (env :host) "localhost"))
        ]
    (server app port host 100000000)))
