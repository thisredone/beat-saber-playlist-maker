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

    <div class="flex flex-row">

      <div class="flex flex-col px-4">
        <div class="font-bold text-xl">Playlists</div>
        <div v-for="playlist in playlists"
             @click="showPlaylist(playlist)"
             class="hover:underline cursor-pointer">
          {{ playlist.playlistTitle }}
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

  watch:
    gameDir: ->
      return if not @gameDir?
      @playlists = []
      fs.readdir @path('Playlists'), (err, files) =>
        return @alert("Could not read playlists: #{ err.message }") if err
        for file in files then do (file) =>
          return if file == 'favorites.json'
          fs.readFile @path('Playlists', file), (err, file) =>
            return @alert("Could not read playlist #{ file }: #{ err.message }") if err
            try
              @playlists.push JSON.parse(file.toString())
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
      path.join(@gameDir, paths...)

    showPlaylist: (playlist) ->
      log playlist
</script>

<style lang="stylus">
</style>
