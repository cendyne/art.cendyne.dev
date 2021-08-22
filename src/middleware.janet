(use joy)
(use janetls)
(import json)
(import ./secrets)

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

(defn file-uploads
  `This middleware attempts parse multipart form bodies
   and saves temp files for each part with a filename
   content disposition

   The tempfiles are deleted after your handler is called

   It then returns the body as an array of dictionaries like this:

   @[{:filename "name of file" :content-type "content-type" :size 123 :tempfile "<file descriptor>"}]`
  [handler]
  (fn [request]
    (if (and (get request :body)
             (or (post? request) (put? request))
             (http/multipart? request))
      (let [body (http/parse-multipart-body request)
            request (put request :multipart-body body)
            request (put request :body nil)
            response (handler request)
            files (as-> body ?
                        (map |(get $ :temp-file) ?)
                        (filter truthy? ?))]
        (loop [f :in files] # delete temp files
          (file/close f))
        response)
      (handler request))))

(defn with-authentication [handler]
  (fn [request]
    (def token (get-in request [:authorization :data]))
    (if (constant= (secrets/admin-token) token)
      (handler request)
      @{
        :status 401
        :body "Unauthorized"
      })))

(defn www-url-form [handler]
  (fn [request]
    (let [{:body body} request]
      (if (and body (form? request))
        (handler (merge request {
          :body (http/parse-body body)
          :original-body body
          }))
        (handler request)))))

(defn json [handler]
  (fn [request]
    (let [{:body body} request]
      (if (and body
               (json? request))
        (handler (merge request {
          :body (json/decode body true)
          :original-body body
          }))
        (handler request)))))

(def- default-json @{
  :status 200
  :headers @{
    "Content-Type" "application/json"
  }
  :body "{}"
  })

(defn with-json-body
  [handler]
  (fn [request]
    (let [
      response (handler request)
      body (if (dictionary? response) (get response :body))
      ]
      (cond
      (= "" body) response
      body (merge (merge default-json response) @{:body (json/encode body)})
      (nil? response) default-json
      # Otherwise
      true (merge default-json @{:body (json/encode response)})
      ))))
