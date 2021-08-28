(use joy)
(use janetls)

(defn- generate-id [bytes] (encoding/encode (util/random bytes) :base64 :url-unpadded))

(defn- recursive-short-id [bytes iterations]
  # This may indicate a database problem..
  (if (> iterations 128) (error "An internal error has occurred, too many iterations"))
  (def public-id (generate-id bytes))
  (try
    (do
      (if
        (and
          (not (string/has-prefix? "-" public-id))
          (not (string/has-prefix? "_" public-id))
          (not (string/has-suffix? "-" public-id))
          (not (string/has-suffix? "_" public-id))
          (db/insert :short-id {:public-id public-id}))
        # Success
        public-id
        # Something failed, so recurse
        (recursive-short-id bytes (+ 1 iterations)))
      )
    ([err fib] (try
    # In the rare chance (1%) of a collision,
    # just try again
    (recursive-short-id bytes (+ 1 iterations))
    # error with the original error at this point
    ([err2 fib2] (propagate err fib))
    ))))

# Just generate a 48 bit ID instead of hitting the db to dynamically scale
(defn new [] (recursive-short-id 6 0))
