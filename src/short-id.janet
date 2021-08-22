(use joy)
(use janetls)

(defn- generate-id [bytes] (encoding/encode (util/random bytes) :base64 :url-unpadded))

(defn- recursive-short-id [bytes iterations]
  # This may indicate a database problem..
  (if (> iterations 32) (error "An internal error has occurred, too many iterations"))
  (def public-id (generate-id bytes))
  (try (do 
    (if
      (db/insert :short-id {:public-id public-id})
      public-id)
    ) ([err fib] (try
    # In the rare chance (1%) of a collision,
    # just try again
    (recursive-short-id bytes (+ 1 iterations))
    # error with the original error at this point 
    ([err2 fib2] (propagate err fib))
    ))))

# Just generate a 32 bit ID instead of hitting the db
(defn new [] (recursive-short-id 4 0))
