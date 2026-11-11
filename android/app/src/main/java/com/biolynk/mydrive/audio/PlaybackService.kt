package com.biolynk.mydrive.audio

import android.content.ContentResolver
import android.net.Uri
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.LibraryResult
import androidx.media3.session.MediaLibraryService
import androidx.media3.session.MediaSession
import com.biolynk.mydrive.MyDriveApp
import com.biolynk.mydrive.R
import com.biolynk.mydrive.metrics.Metrics
import com.google.common.collect.ImmutableList
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.MoreExecutors

/**
 * The car-screen side on Android Auto: a media library with Today / Library / Drives.
 * Playing "welcome" queues the theme sound, then the spoken briefing; when the queue ends the
 * audio focus is released so the user's music app takes over.
 */
class PlaybackService : MediaLibraryService() {

    private lateinit var player: ExoPlayer
    private var session: MediaLibrarySession? = null
    private val app get() = application as MyDriveApp

    override fun onCreate() {
        super.onCreate()
        player = ExoPlayer.Builder(this)
            .setAudioAttributes(
                AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_SPEECH).build(),
                /* handleAudioFocus = */ true
            ).build()
        player.addListener(object : Player.Listener {
            override fun onMediaItemTransition(item: MediaItem?, reason: Int) {
                when (item?.mediaId) {
                    ID_THEME -> app.metrics.log(Metrics.Event.WELCOME_STARTED, mapOf("theme" to app.store.theme))
                    ID_BRIEFING_AUDIO -> {
                        app.metrics.log(Metrics.Event.WELCOME_FINISHED)
                        app.metrics.log(Metrics.Event.BRIEFING_STARTED)
                    }
                }
            }
            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_ENDED) {
                    app.metrics.log(Metrics.Event.BRIEFING_FINISHED)
                    player.clearMediaItems() // releases audio focus -> user's music resumes
                    app.metrics.log(Metrics.Event.HANDOFF_MUSIC)
                }
            }
        })
        session = MediaLibrarySession.Builder(this, player, Callback()).build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaLibrarySession? {
        if (controllerInfo.packageName == ANDROID_AUTO_PKG) {
            app.metrics.log(Metrics.Event.APP_LAUNCHED, mapOf("surface" to "android_auto"))
        }
        return session
    }

    override fun onDestroy() {
        session?.run { player.release(); release() }
        session = null
        super.onDestroy()
    }

    private inner class Callback : MediaLibrarySession.Callback {

        override fun onGetLibraryRoot(
            session: MediaLibrarySession, browser: MediaSession.ControllerInfo, params: LibraryParams?
        ): ListenableFuture<LibraryResult<MediaItem>> =
            Futures.immediateFuture(LibraryResult.ofItem(folder(ID_ROOT, "My Drive"), params))

        override fun onGetChildren(
            session: MediaLibrarySession, browser: MediaSession.ControllerInfo, parentId: String,
            page: Int, pageSize: Int, params: LibraryParams?
        ): ListenableFuture<LibraryResult<ImmutableList<MediaItem>>> {
            val items = when (parentId) {
                ID_ROOT -> listOf(folder(ID_TODAY, "Today"), folder(ID_LIBRARY, "Library"), folder(ID_DRIVES, "Drives"))
                ID_TODAY -> listOf(playable(ID_WELCOME, welcomeTitle(), "Welcome theme + briefing"),
                    playable(ID_BRIEFING, "Today's briefing", "Weather · first event · traffic"))
                ID_LIBRARY -> THEMES.map { playable("$ID_THEME_PREFIX$it", it.replaceFirstChar(Char::uppercase), "Welcome theme") }
                ID_DRIVES -> listOf(playable(ID_WELCOME, "Recent drives appear here", ""))
                else -> emptyList()
            }
            return Futures.immediateFuture(LibraryResult.ofItemList(ImmutableList.copyOf(items), params))
        }

        override fun onGetItem(
            session: MediaLibrarySession, browser: MediaSession.ControllerInfo, mediaId: String
        ): ListenableFuture<LibraryResult<MediaItem>> =
            Futures.immediateFuture(LibraryResult.ofItem(playable(mediaId, welcomeTitle(), ""), null))

        /** Resolve browse items into the real queue: theme sound + synthesised briefing. */
        override fun onAddMediaItems(
            mediaSession: MediaSession, controller: MediaSession.ControllerInfo, mediaItems: MutableList<MediaItem>
        ): ListenableFuture<MutableList<MediaItem>> {
            val id = mediaItems.firstOrNull()?.mediaId ?: ID_WELCOME
            if (controller.packageName == ANDROID_AUTO_PKG) app.metrics.markConnect(mapOf("via" to "android_auto_play"))
            return buildQueue(withTheme = id != ID_BRIEFING)
        }

        /** Android Auto calls this on connect when the user allows media to resume: our welcome. */
        override fun onPlaybackResumption(
            mediaSession: MediaSession, controller: MediaSession.ControllerInfo
        ): ListenableFuture<MediaSession.MediaItemsWithStartPosition> {
            if (!app.store.welcomeOnConnect) {
                return Futures.immediateFailedFuture(UnsupportedOperationException("welcome off"))
            }
            app.metrics.markConnect(mapOf("via" to "resumption"))
            return Futures.transform(buildQueue(withTheme = true),
                { MediaSession.MediaItemsWithStartPosition(it, 0, 0L) }, MoreExecutors.directExecutor())
        }
    }

    private fun buildQueue(withTheme: Boolean): ListenableFuture<MutableList<MediaItem>> {
        val profile = app.store.loadProfile()
        val art = ArtworkComposer.jpeg(
            ArtworkComposer.compose(profile?.let { app.store.carBitmap(it.slug, it.colourId) },
                "Welcome back,", profile?.ownerName?.ifBlank { "Driver" } ?: "Driver")
        )
        val theme = MediaItem.Builder().setMediaId(ID_THEME).setUri(rawUri(R.raw.welcome_signature))
            .setMediaMetadata(meta(welcomeTitle(), "Welcome theme", art)).build()
        val tts = Briefing.synthesize(this, Briefing.text(profile))
        return Futures.transform(tts, { file ->
            val briefing = MediaItem.Builder().setMediaId(ID_BRIEFING_AUDIO).setUri(Uri.fromFile(file))
                .setMediaMetadata(meta("Your drive briefing", profile?.displayName ?: "My Drive", art)).build()
            (if (withTheme) mutableListOf(theme, briefing) else mutableListOf(briefing))
        }, MoreExecutors.directExecutor())
    }

    private fun welcomeTitle(): String {
        val name = app.store.loadProfile()?.ownerName.orEmpty()
        return if (name.isBlank()) "Welcome back" else "Welcome back, $name"
    }

    private fun rawUri(res: Int) = Uri.Builder().scheme(ContentResolver.SCHEME_ANDROID_RESOURCE)
        .authority(packageName).appendPath(res.toString()).build()

    private fun meta(title: String, subtitle: String, art: ByteArray? = null) = MediaMetadata.Builder()
        .setTitle(title).setArtist(subtitle).setIsPlayable(true).setIsBrowsable(false)
        .apply { art?.let { setArtworkData(it, MediaMetadata.PICTURE_TYPE_FRONT_COVER) } }
        .build()

    private fun folder(id: String, title: String) = MediaItem.Builder().setMediaId(id).setMediaMetadata(
        MediaMetadata.Builder().setTitle(title).setIsBrowsable(true).setIsPlayable(false)
            .setMediaType(MediaMetadata.MEDIA_TYPE_FOLDER_MIXED).build()
    ).build()

    private fun playable(id: String, title: String, subtitle: String) =
        MediaItem.Builder().setMediaId(id).setMediaMetadata(meta(title, subtitle)).build()

    companion object {
        const val ANDROID_AUTO_PKG = "com.google.android.projection.gearhead"
        const val ID_ROOT = "root"; const val ID_TODAY = "today"; const val ID_LIBRARY = "library"; const val ID_DRIVES = "drives"
        const val ID_WELCOME = "welcome"; const val ID_BRIEFING = "briefing"
        const val ID_THEME = "theme"; const val ID_BRIEFING_AUDIO = "briefing_audio"; const val ID_THEME_PREFIX = "theme:"
        val THEMES = listOf("signature", "calm", "grand")
    }
}
