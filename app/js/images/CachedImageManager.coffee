createId = -> 
  'xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace(/[xy]/g, (c) ->
    r = Math.random()*16|0
    v = if c == 'x' then r else (r&0x3|0x8)
    return v.toString(16)
   )


# cachePath: e.g. "Android/data/<url reversed>/images" 
# apiUrl: e.g. http://api.mwater.co/v3/
# client: client id for uploading
# fileTransfer: FileTransfer instance
module.exports = class CachedImageManager
  constructor: (fs, apiUrl, cachePath, client, fileTransfer) ->
    @fs = fs
    @apiUrl = apiUrl
    @cachePath = cachePath
    @client = client
    @fileTransfer = fileTransfer

  addImage: (url, success, error) ->
    # Create an id
    id = createId()

    # Get file
    resolveLocalFileSystemURI = window.resolveLocalFileSystemURI || window.resolveLocalFileSystemURL || window.webkitResolveLocalFileSystemURL

    resolveLocalFileSystemURI url, (fileEntry) =>
      # Move file
      @getDirectory @cachePath + "/pending/original", (dirEntry) ->
        console.log "Moving file to: " + dirEntry.fullPath + "/" + id + ".jpg"
        fileEntry.moveTo dirEntry, id + ".jpg", =>
          success(id)
        , error
      , error
    , error
      
  # Gets a directory, creating if necessary. Call success with dirEntry
  getDirectory: (dir, success, error) ->
    @createDirs @fs.root, dir, success, error

  createDirs: (baseDirEntry, path, success, error) ->
    segs = path.split("/")
    if segs.length is 1
      baseDirEntry.getDirectory segs[0],
        create: true
      , success, error
    else
      baseDirEntry.getDirectory segs[0],
        create: true
      , ((dir) =>
        @createDirs dir, segs.slice(1).join("/"), success, error
      ), error

  # Gets an image, calling success with url 
  getImageUrl: (imageId, success, error) ->
    console.log "getImageUrl:" + imageId
    @loadOrDownloadImage [@cachePath + "/cached/1280h", @cachePath + "/cached/original", @cachePath + "/pending/original"],
      @apiUrl + "images" + "/" + imageId + "?h=1280", 
      @cachePath + "/cached/1280h", 
      imageId, success, error

  # Gets a thumbnail image, calling success with url 
  getImageThumbnailUrl: (imageId, success, error) ->
    console.log "getImageThumbnailUrl:" + imageId
    @loadOrDownloadImage [@cachePath + "/cached/160h", @cachePath + "/cached/1280h", @cachePath + "/cached/original", @cachePath + "/pending/original"],
      @apiUrl + "images" + "/" + imageId + "?h=160", 
      @cachePath + "/cached/160h", 
      imageId, success, error

  loadOrDownloadImage: (dirs, remoteUrl, downloadDir, imageId, success, error) ->
    # If no directories left to try, call download
    if dirs.length is 0
      @getDirectory downloadDir, ((dirEntry) =>
        @downloadImage imageId, remoteUrl, dirEntry, success, error
      ), error
      return
    
    # Try each directory in dirs, using recursion
    @findImageFile _.first(dirs), imageId, ((url) -> # Found
      success url
    ), ((url) => # Not found
      @loadOrDownloadImage _.rest(dirs), remoteUrl, downloadDir, imageId, success, error
    ), error

  downloadImage: (imageId, url, dirEntry, success, error) ->
    @fileTransfer.download encodeURI(url), dirEntry.toURL() + "/" + imageId + ".jpg", ((entry) ->
      success entry.toURL()
    ), (err) ->
      # Delete file on disk if present
      dirEntry.getFile imageId + ".jpg", {}, (imageFile) ->
        imageFile.remove ->
          error(err)
        , ->
          error(err)
      , ->
        error(err)

  findImageFile: (dir, imageId, found, notfound, error) ->
    console.log "checking in: " + dir
    
    # Get directory
    @getDirectory dir, ((dirEntry) ->
      
      # Get file if present
      dirEntry.getFile imageId + ".jpg", {}, ((imageFile) ->
        
        # File present, display file
        found imageFile.toURL()
      ), (err) ->
        if err.code is FileError.NOT_FOUND_ERR
          notfound()
        else
          error err
    ), error

  numPendingImages: (success, error) ->
    # Copy file to pending folder
    @getDirectory @cachePath + "/pending/original", (dirEntry) =>
      
      # Get a list of all the entries in the directory
      dirEntry.createReader().readEntries (files) =>
        success(files.length)
      , error
    , error

  # Upload one image to server. Success is called with number of images remaining.
  upload: (success, error) ->
    # Copy file to pending folder
    @getDirectory @cachePath + "/pending/original", (dirEntry) =>
      
      # Get a list of all the entries in the directory
      dirEntry.createReader().readEntries (files) =>
        if files.length is 0
          success 0
          return

        console.log "#{files.length} images to upload"
       
        uploadSuccess = =>
          # Success uploading, move to cache
          @getDirectory @cachePath + "/cached/original", (dirEntry) ->
            files[0].moveTo dirEntry, files[0].name, ->
              # File moves, call success
              console.log "Successful image upload"
              success files.length - 1
            , error
          , error

        uploadError = (fileTransferError) ->
          if fileTransferError.http_status is 409
            # Image already exists, delete file
            # Success uploading, delete file
            files[0].remove ->
              # File removed, call success
              success files.length - 1
            , error
          else
            error fileTransferError

        # Upload file
        fileName = files[0].toURL()
        destUrl = encodeURI(@apiUrl + "images/" + files[0].name.split(".")[0] + "?client=" + @client)
        console.log "About to upload image #{fileName} to #{destUrl}"
        @fileTransfer.upload fileName, destUrl, 
          uploadSuccess, uploadError, { fileKey: "image" }
      , error
    , error
