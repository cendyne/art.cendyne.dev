(use janetls)

(def- authorization-parser (peg/compile '{
  :S+ (some :S)
  :basic (sequence '"Basic" :s+ (constant :token) (capture :S+) :s*)
  :bearer (sequence '"Bearer" :s+ (constant :token) (capture :S+) :s*)
  :keyword (<- (some (choice :w "-" "_" "/" "%")))
  :value (* (+
    (* "\"" (<- (some (if-not (+ "," "\"") :S))) "\"")
    (<- (some (if-not "," :S)))
  ))
  :parameter (* :keyword "=" :value)
  :keyword-pair (* :keyword (+ (* "=" :value) (constant "")))
  :keyword-pairs (*
    :keyword-pair
    (any (* "," :s* :keyword-pair))
    )
  :other (* :keyword (? (* :s+ (+
    (* (constant :pairs) :keyword-pairs)
    (* (constant :token) (capture :S+))
    ))))
  :main (choice :basic :bearer :other)
}))

(defn- build-data-table [parts]
  (def data @{})
  (while (not (empty? parts))
    (def value (array/pop parts))
    (def key (keyword (array/pop parts)))
    (put data key value)
    )
  data)

(defn- parse-authorization-header [header]
  (if-let [parts (peg/match authorization-parser header)]
    (do
      (def first (get parts 0))
      (case first
        "Bearer" {:type :bearer :data (get parts 2)}
        "Basic" (do
          (def decoded (base64/decode (get parts 2)))
          (def credential (string/split ":" decoded 0 2))
          {:type :digest :data {
            :username (get credential 0)
            :password (get credential 1)
          }})
        (case (get parts 1)
          :token {:type first :data (get parts 2)}
          :pairs {:type first :data (build-data-table (array/slice parts 2))}
          )))))

(defn authorization [handler]
  (fn [request]
    (let [
      {:headers headers} request
      authorization (or (get headers :authorization) (get headers "Authorization") (get headers "authorization"))
      data (if authorization (parse-authorization-header authorization))
      ]
      (if data
        (handler (merge request {:authorization data}))
        (handler request)))))
