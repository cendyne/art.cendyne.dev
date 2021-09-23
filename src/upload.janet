(use joy)
(import ./art)
(import ./background)

(def- common-formats [
  "image/jpeg"
  "image/png"
  "image/webp"
  "image/avif"
  "image/jxl"
])

(defn get-file [id]
  (cond
    (number? id) (art/find-file id)
    (bytes? id) (art/find-file-by-public-id id)
    (errorf "Unsure how to load file with %p" id)
  ))
(defn get-original-upload [id]
  (cond
    (number? id) (art/find-original-upload id)
    (bytes? id) (art/find-original-upload-by-public-id id)
    (errorf "Unsure how to load original-upload with %p" id)
  ))
(defn get-pending-upload [id]
  (cond
    (number? id) (art/find-pending-upload id)
    (bytes? id) (art/find-pending-upload-by-public-id id)
    (errorf "Unsure how to load pending-upload with %p" id)
  ))

(defn- populate-pending-upload [original-upload pending-upload]
  (def items @[])
  (def file (get-file (get pending-upload :file-id)))
  (def result @{
    :file file
    :original-name (get file :original-name)
    :original-upload original-upload
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
    (put result :progress (/ completed total)))
  result)

(defn upload-original [file content-type filesize original-name]
  (def digest (art/digest-uploaded-file temp-file))
  (def existing-file (art/find-file-by-digest digest))
  (def [file original-upload] (if existing-file
    (do
      (var original-upload (art/find-original-upload-by-file-id (get existing-file :id)))
      (unless original-upload
        (set original-upload (art/create-original-upload file)))
      [existing-file original-upload])
    (do
      (def [public-path filename] (art/new-file-names content-type))
      (art/write-uploaded-file temp-file filename)
      (def file (art/create-file public-path digest content-type original-name filesize))
      (def original-upload (art/create-original-upload file))
      [file original-upload])))
  (def pending-upload (art/create-pending-upload file original-upload))
  @{
    :file file
    :original-name original-name
    :original-upload original-upload
    :pending-upload pending-upload
  })

(defn web-image [file original-upload pending-upload]
  (unless original-upload (errorf "Missing original-upload"))
  (unless pending-upload (errorf "Missing pending-upload"))
  (unless file (errorf "Missing file"))
  (each content-type common-formats
    (art/create-pending-upload-item pending-upload content-type))
  # Submit to process items
  (background/submit-to-process pending-upload)
  # Build result
  (populate-pending-upload original-upload pending-upload))

# Load pending upload by pending upload public id
(defn load-pending-upload [public-id]
  (def pending-upload (art/find-pending-upload-by-public-id public-id))
  (when pending-upload
    (def original-upload (art/find-original-upload-by-file-id (get pending-upload :file-id)))
    (when original-upload
      (populate-pending-upload original-upload pending-upload))))

# TODO
# TODO: Create Art from original-upload, pending-upload, and pending-upload-items, and tags
# TODO: Delete pending-upload and pending-upload-items


