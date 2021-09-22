(use joy)

(import ./secrets)
(import ./background)

(defn initialize []
  (unless (secrets/load-secrets) (error "Could not load secrets"))
  (db/migrate (env :database-url))
  # Run this before starting a connection, those don't cross over
  (background/background-worker)
  # Start a connection for the application
  (db/connect (env :database-url))
  )
