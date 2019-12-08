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
        <button @click="addSongs" class="px-2 border focus:outline-none hover:bg-gray-100 mb-2">Add Songs</button>

        <div v-if="browsingSongs">

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

  watch:
    gameDir: ->
      return if not @gameDir?
      @playlists = []
      fs.readdir @path('Playlists'), (err, files) =>
        return @alert("Could not read playlists: #{ err.message }") if err
        for file in files then do (file) =>
          return if file == 'favorites.json'
          fs.readFile @path('Playlists', file), (err, content) =>
            return @alert("Could not read playlist #{ file }: #{ err.message }") if err
            try
              playlist = JSON.parse(content.toString())
              playlist._filename = file
              @playlists.push playlist
            catch e
              return @alert("Playlist #{ file } is not JSON")

      fs.readdir @path('Beat Saber_Data', 'CustomLevels'), (err, files) =>
        return @alert("Could not read songs: #{ err.message }") if err

  created: ->
    window.app = this
    @gameDir = 'D:\\SteamLibrary\\steamapps\\common\\Beat Saber'

  methods:
    setGameDir: ->
      dir = @$refs.bsaberDirPicker.files[0].path
      fs.access path.join(dir, 'Beat Saber_Data'), fs.constants.F_OK, (err) =>
        if err
          @alert 'Game Directory should have Beat Saber_Data directory'
        else
          @gameDir = dir

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
      @browsingSongs = false
      @changingName = false

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

    savePlaylist: ->
      name = @currentPlaylist._filename
      content = JSON.stringify @currentPlaylist
      fs.writeFile @path('Playlists', name), content, (err, res) =>
        return @alert("Couldn't save file: #{ err.message }") if err
        @alert('Playlist saved')

    addSongs: ->
      @browsingSongs = true

    removeSong: (index) ->
      @currentPlaylist.songs.splice(index, 1)

</script>

<style lang="stylus">
</style>
