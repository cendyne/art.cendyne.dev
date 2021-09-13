(use joy)

(import ./secrets)

(defn initialize []
  (unless (secrets/load-secrets) (error "Could not load secrets"))
  (db/migrate (env :database-url))
  (db/connect (env :database-url))
  )
