(use joy)
(import sh)
(import json)
(use janetls)

(def- submit-chan (ev/thread-chan 30))
(defn submit-async [work] (ev/give submit-chan work))
(defn- worker []
  (forever
    (def work (ev/take submit-chan))
    (ev/sleep 1)
    (printf "Got work %p %p" work (length (encoding/encode work :base64)))

    ))
(defn begin-worker []
  (ev/spawn-thread
    (ev/call worker)))

(begin-worker)
(submit-async "Hello")
(submit-async "Hi")
