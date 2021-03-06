(use joy)
(use janetls)

(defn- env-secret [secret &opt encoding]
  (let [value (dyn secret)] (if value value (let
    [value (env secret)
    ] (if value
    (do
      (def value (if encoding (encoding/decode value encoding) value))
      (setdyn secret value)
      value)
    (errorf
      "The secret %s was not set as an environment variable or .env value"
      (string/replace-all "-" "_" (string/ascii-upper (string secret)))
      ))
  ))))

(defn admin-token [] (env-secret :admin-token))
(defn lq-base-url [] (env-secret :lq-base-url))
(defn lq-token [] (env-secret :lq-token))
(defn session-key [] (env-secret :session-key :hex))
(defn csrf-key [] (env-secret :csrf-key :hex))

(defn load-secrets [] (and
  (admin-token)
  (lq-base-url)
  (lq-token)
  (csrf-key)
  (session-key)
  true))