<template>
  <div id="app" class="subpixel-antialiased text-gray-700">

    <div class="text-center">
      <div v-show="alerts.length" class="fixed z-40 top-0 right-0 px-6 py-4 bg-teal-300">
        <div v-for="alert in alerts">{{ alert }}</div>
      </div>

      <h1 class="text-3xl my-8">Beat Saber Playlist Maker</h1>

      <div>Game Files: {{ gameDir }}</div>

      <button @click="$refs.bsaberDirPicker.click()"
              class="px-2 border bg-gray-200 border-gray-300 hover:bg-gray-100 focus:outline-none">
        Change
      </button>
      <input @change="setGameDir" ref="bsaberDirPicker" type="file" webkitdirectory class="hidden"/>

      <hr class="my-8">
    </div>

    <div v-if="gameDir" class="flex flex-row">

      <div class="flex flex-col px-4">
        <div class="font-bold text-xl">Playlists</div>
        <div v-for="playlist in playlists"
             @click="showPlaylist(playlist)"
             class="hover:underline cursor-pointer">
          {{ playlist.playlistTitle }}
        </div>

        <button v-if="showCreatePlaylistBtn"
                @click="newPlaylist"
                class="mt-1 border focus:outline-none hover:bg-gray-100 px-2">
          Create New
        </button>
      </div>

      <div v-if="currentPlaylist" class="flex-grow flex flex-col mx-4">

        <div v-if="confirmingRemoval" class="text-center">
          <h3 class="text-xl">Are you sure you want to remove this playlist?</h3>
          <br>
          <button @click="confirmingRemoval = false" class="border px-4 hover:bg-teal-100">No</button>
          <button @click="removePlaylist" class="border px-4 hover:bg-teal-100 ml-10">Yes</button>
        </div>

        <div class="text-right">
          <button @click="confirmingRemoval = true"
                  class="border px-2 text-gray-500 hover:text-gray-700 hover:border-gray-400">
            remove playlist
          </button>
        </div>

        <div class="text-2xl text-center mb-4">
          <input v-model="currentPlaylist.playlistTitle"
                 ref="playlistName"
                 v-if="changingName"
                 @keyup.enter="changingName = false"
                 type="text"
                 class="text-center border">
          <h2 v-else @click="startChangingName">{{ currentPlaylist.playlistTitle }}</h2>
        </div>

        <button @click="savePlaylist" class="px-2 border focus:outline-none hover:bg-gray-100 mb-2">Save Playlist</button>
        <button @click="removeDuplicates" class="px-2 border focus:outline-none hover:bg-gray-100 mb-2">Remove duplicates</button>
        <button @click="browsingSongs = !browsingSongs"
                class="px-2 border focus:outline-none hover:bg-gray-100 mb-2">
          {{ browsingSongs ? 'See Added Songs' : 'Add Songs' }}
        </button>

        <div v-if="browsingSongs" class="shadow-lg p-2 flex flex-col">
          <div class="flex justify-between">
            <label class="font-bold">
              Search:
              <input class="border-b focus:outline-none px-2 mb-2 ml-2" v-model="songFilter" type="text">
            </label>
            <div class="self-center flex">
              <button @click="addAllUnplaylisted"
                      v-if="!addingAllSongs"
                      class="border px-2 text-sm hover:text-black hover:border-gray-400 mr-2">
                Add unplaylisted
              </button>
              <button @click="addAllToPlaylist"
                      v-if="!addingAllSongs"
                      class="border px-2 text-sm hover:text-black hover:border-gray-400">
                Add all
              </button>
            </div>
          </div>
          <div>
            <div v-for="song in filteredSongs"
                 @click="addToPlaylist(song)"
                 class="cursor-pointer hover:underline">
              {{ song.__label }}
            </div>
          </div>
        </div>

        <div v-else v-for="(song, index) in currentPlaylist.songs" class="mb-1">
          <button @click="removeSong(index)" class="px-1 mr-2 border text-sm hover:bg-gray-100">X</button>
          {{ song.songName || song.hash }}
        </div>

      </div>

    </div>
  </div>
</template>

<script lang="coffee">
{ remote } = require 'electron'
fs = remote.require 'fs'
crypto = remote.require 'crypto'
path = remote.require 'path'

export default
  data: ->
    gameDir: null
    alerts: []
    playlists: []
    songs: []
    showCreatePlaylistBtn: true
    currentPlaylist: null
    browsingSongs: false
    changingName: false
    confirmingRemoval: false
    songFilter: ''
    addingAllSongs: false
    hashToLabel: null

  computed:
    filteredSongs: ->
      filter = @songFilter.trim().toLowerCase()
      return @songs if filter is ''
      @songs.filter (s) ->
        s.__label.toLowerCase().includes filter

  watch:
    gameDir: ->
      return if not @gameDir?
      @playlists = []
      @songs = []

      fs.readdir @path('Playlists'), (err, files) =>
        return @alert("Could not read playlists: #{ err.message }") if err
        files.forEach (file) =>
          return if file is 'favorites.json' or file.split('.').last() not in ['bplist', 'json']
          @readJson @path('Playlists', file), (playlist) =>
            playlist._filename = file
            @playlists.push playlist

      @loadSongs @path('Beat Saber_Data', 'CustomLevels')

      songCoreFoldersConfigFile = @path('UserData', 'SongCore', 'folders.xml')
      fs.access songCoreFoldersConfigFile, fs.constants.F_OK, (err) =>
        return if err
        fs.readFile songCoreFoldersConfigFile, 'UTF-8', (err, content) =>
          return if err
          doc = (new DOMParser).parseFromString(content, 'text/xml')
          doc.querySelectorAll('folder').forEach (folder) =>
            if folder.querySelector('Pack').textContent is '0'
              @loadSongs folder.querySelector('Path').textContent

  created: ->
    fs.access 'config.json', fs.constants.F_OK, (err) =>
      return if err
      @readJson 'config.json', ({ @gameDir }) =>

  methods:
    setGameDir: ->
      dir = @$refs.bsaberDirPicker.files[0].path
      fs.access path.join(dir, 'Beat Saber_Data'), fs.constants.F_OK, (err) =>
        if err
          @alert 'Game Directory should have Beat Saber_Data directory'
        else
          @showPlaylist(null)
          @gameDir = dir
          fs.writeFile 'config.json', JSON.stringify({ @gameDir }), ->

    loadSongs: (songsDir) ->
      fs.readdir songsDir, (err, dirs) =>
        return @alert("Could not read songs: #{ err.message }") if err
        dirs.forEach (dir) =>
          @readJson path.join(songsDir, dir, 'info.dat'), (song) =>
            song._dir = path.join(songsDir, dir)
            author = song._songAuthorName
            if not author? or author.trim().length is 0 or author.match(/^(Mapped )?by/)?
              author = song._levelAuthorName
            song.__label = "#{ author } - #{ song._songName }"
            @songs.push song

    fillHashToLabel: ->
      return if @hashToLabel?
      @hashToLabel = {}
      Promise.all @songs.map (song) =>
        metadataPath = path.join(song._dir, 'metadata.dat')
        new Promise (resolve) =>
          fs.access metadataPath, fs.constants.F_OK, (err) =>
            return resolve() if err
            @readJson metadataPath, resolve, (metadata) =>
              @hashToLabel[metadata.hash] = song.__label
              resolve()

    alert: (text) ->
      @alerts.push text
      await after 4000
      for t, i in @alerts by -1
        if t is text
          @alerts.splice(i, 1)
          break
      null

    path: (paths...) ->
      path.join @gameDir, paths...

    showPlaylist: (playlist) ->
      @currentPlaylist = playlist
      if playlist?
        if not @hashToLabel and @currentPlaylist.songs.some (s) -> not s.songName?
          await @fillHashToLabel()
        fixedCount = 0
        for song, i in @currentPlaylist.songs when not song.songName?
          song.songName = @hashToLabel[song.hash]
          fixedCount++ if song.songName?
          @$set @currentPlaylist.songs, i, song
        @savePlaylist("Corrected #{ fixedCount } entries") if fixedCount

      @browsingSongs = false
      @changingName = false
      @confirmingRemoval = false
      @songFilter = ''

    newPlaylist: ->
      @showCreatePlaylistBtn = false
      pl =
        playlistTitle: 'New Playlist'
        playlistAuthor: 'me'
        playlistDescription: ''
        _filename: "Playlist#{ Date.now() }.json"
        songs: []
      @playlists.push pl
      @showPlaylist pl
      @startChangingName()
      await after 1000
      @showCreatePlaylistBtn = true

    startChangingName: ->
      @changingName = true
      @$nextTick =>
        @$refs.playlistName.select()

    savePlaylist: (reason) ->
      @alert(reason) if reason?
      name = @currentPlaylist._filename
      content = JSON.stringify @currentPlaylist
      fs.writeFile @path('Playlists', name), content, (err, res) =>
        return @alert("Couldn't save file: #{ err.message }") if err
        @alert 'Playlist saved'

    removeSong: (index) ->
      @currentPlaylist.songs.splice(index, 1)

    removeDuplicates: ->
      hashes = {}
      removedCount = 0
      for song, i in @currentPlaylist.songs by -1
        if hashes[song.hash]
          removedCount++
          @currentPlaylist.songs.splice(i, 1)
        hashes[song.hash] = true
      if removedCount
        @savePlaylist "Removed #{ removedCount } duplicates"
      else
        @alert 'There are no duplicates here'

    readJson: (file, onError, cb) ->
      [cb, onError] = [onError, cb] if not cb?
      fs.readFile file, 'UTF-8', (err, content) =>
        return onError() if err and onError?
        return @alert("Couldn't read #{ file }: #{ err.message }") if err
        try
          cb JSON.parse(content), content
        catch e
          return onError() if onError?
          @alert("File #{ file } is not JSON: #{ e.message }")

    createMetadata: (songDir) ->
      new Promise (resolve) =>
        @readJson path.join(songDir, 'info.dat'), (info, infoRaw) ->
          toHash = infoRaw
          for set in info._difficultyBeatmapSets
            for map in set._difficultyBeatmaps
              toHash += fs.readFileSync(path.join(songDir, map._beatmapFilename), 'UTF-8')
          hash = crypto.createHash('sha1').update(toHash).digest('hex')
          metadata = JSON.stringify({ hash, scannedTime: Date.now() })
          fs.writeFile path.join(songDir, 'metadata.dat'), metadata, (err) =>
            return @alert("Couldn't save #{ path.join(songDir, 'metadata.dat') }: #{ err.message }") if err
            resolve()

    addToPlaylist: (song, { silent, notThese } = {}) ->
      metadataPath = path.join(song._dir, 'metadata.dat')
      new Promise (resolve) =>
        fs.access metadataPath, fs.constants.F_OK, (err) =>
          if err
            await @createMetadata(song._dir)
            @alert("Created metadata.dat for #{ song.__label }") if not silent
          @readJson metadataPath, (metadata) =>
            if notThese?.has(metadata.hash)
              resolve(false)
            else if @currentPlaylist.songs.some (s) -> s.hash is metadata.hash
              resolve(false)
            else
              @currentPlaylist.songs.push(hash: metadata.hash, songName: song.__label)
              @alert("Added #{ song.__label }") if not silent
              resolve(true)

    addAllToPlaylist: ({ notThese } = {}) ->
      @addingAllSongs = true
      added = 0
      await Promise.all @filteredSongs.map (s) =>
        added++ if await @addToPlaylist(s, { notThese, silent: true })
      @alert "Added #{ added } songs"
      @addingAllSongs = false
      @browsingSongs = false

    addAllUnplaylisted: ->
      playlisted = new Set((@playlists.map (p) -> p.songs.map (s) -> s.hash).flat())
      @addAllToPlaylist(notThese: playlisted)

    removePlaylist: ->
      @confirmingRemoval = false
      fs.unlink @path('Playlists', @currentPlaylist._filename), (err) =>
        return @alert("Couldn't remove #{ @currentPlaylist._filename }: #{ err.message }") if err
        @alert("Removed playlist #{ @currentPlaylist._filename }")
        @playlists.splice(@playlists.indexOf(@currentPlaylist), 1)
        @showPlaylist(null)

</script>
