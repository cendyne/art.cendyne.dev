(use joy)
(import art)

(def- common-formats [
  "image/jpeg"
  "image/png"
  "image/webp"
  "image/avif"
  "image/jxl"
])

(defn web-image [file]
  (def pending-upload (art/create-pending-upload file))
  (def items @[])
  (def result @{
    :pending-upload pending-upload
    :pending-upload-items items
    :status :incomplete
    :progress 0
    })
  (each content-type common-formats
    (array/push items (art/create-pending-upload-item pending-upload content-type))
    )
  result)

(defn load-pending-upload [public-id]
  (def pending-upload (art/find-pending-upload-by-public-id public-id))
  (when pending-upload
    (def items @[])
    (def result @{
      :pending-upload pending-upload
      :pending-upload-items items
      :progress 1
      })
    (var status :complete)
    (var total 0)
    (var completed 0)
    (def id (get pending-upload :id))
    (each pending-upload-item (art/find-pending-upload-item-by-pending-upload-id id)
      (def file-id (get pending-upload-item :file-id))
      (set total (+ 1 total))
      (unless file-id
        (set status :incomplete))
      (when file-id
        (set completed (+ 1 completed)))
      (array/push items pending-upload-item))
    # Set status for non-numeric value
    (put result :status status)
    # Set progress to completed / total for a percent complete
    (when (< 0 total)
      (put result :progress (/ completed total))
      )
    result))
