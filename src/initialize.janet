(use joy)

(import ./secrets)

(defn initialize []
  (unless (secrets/load-secrets) (error "Could not load secrets"))
  (db/connect (env :database-url))
  )
