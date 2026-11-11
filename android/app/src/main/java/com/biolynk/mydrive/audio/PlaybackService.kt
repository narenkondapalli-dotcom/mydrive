package com.biolynk.mydrive.audio

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
import com.biolynk.mydrive.look.Accent
import com.biolynk.mydrive.look.Scene
import com.biolynk.mydrive.metrics.Metrics
import com.biolynk.mydrive.personal.BriefingItems
import com.biolynk.mydrive.personal.DriveStats
import com.biolynk.mydrive.personal.RitualSettings
import com.biolynk.mydrive.personal.WelcomeSounds
import com.google.common.collect.ImmutableList
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.MoreExecutors
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * The car-screen side on Android Auto: a media library with Today / Library / Drives.
 * Playing "welcome" queues the theme sound, then the spoken briefing; when the queue ends the
 * audio focus is released so the user's music app takes over.
 */
class PlaybackService : MediaLibraryService() {

    private lateinit var player: ExoPlayer
    private var session: MediaLibrarySession? = null
    private val app get() = application as MyDriveApp
    private var welcomeFinished = false
    private var briefingStarted = false

    private fun markWelcomeFinished() {
        if (!welcomeFinished) { welcomeFinished = true; app.metrics.log(Metrics.Event.WELCOME_FINISHED) }
    }

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
                    ID_THEME -> {
                        welcomeFinished = false; briefingStarted = false
                        app.metrics.log(Metrics.Event.WELCOME_STARTED, mapOf("theme" to (app.store.active()?.ritual?.theme ?: WelcomeSounds.DEFAULT_THEME)))
                    }
                    ID_LOVED_ONE -> app.metrics.log(Metrics.Event.LOVED_ONE_PLAYED,
                        mapOf("label" to (app.store.active()?.lovedOne?.label.orEmpty())))
                    ID_DELAY, ID_BRIEFING_AUDIO -> {
                        markWelcomeFinished()
                        if (item.mediaId == ID_BRIEFING_AUDIO) { briefingStarted = true; app.metrics.log(Metrics.Event.BRIEFING_STARTED) }
                    }
                }
            }
            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_ENDED) {
                    markWelcomeFinished()
                    if (briefingStarted) app.metrics.log(Metrics.Event.BRIEFING_FINISHED)
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
                ID_LIBRARY -> WelcomeSounds.THEMES.map { playable("$ID_THEME_PREFIX$it", it.replaceFirstChar(Char::uppercase), "Welcome theme") }
                ID_DRIVES -> driveItems()
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
            val theme = id.removePrefix(ID_THEME_PREFIX).takeIf { id.startsWith(ID_THEME_PREFIX) }
            return buildQueue(withTheme = id != ID_BRIEFING, themeOverride = theme)
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

    private fun buildQueue(withTheme: Boolean, themeOverride: String? = null): ListenableFuture<MutableList<MediaItem>> {
        val dp = app.store.active()
        val profile = dp?.car
        val ritual = dp?.ritual ?: RitualSettings()
        val items = dp?.items ?: BriefingItems()
        val now = LocalDateTime.now()
        val name = profile?.ownerName.orEmpty()
        val greeting = app.store.greetings.pick(now.hour, name, now.dayOfYear)
        val art = ArtworkComposer.jpeg(
            ArtworkComposer.compose(profile?.let { app.store.carBitmap(it.slug, it.colourId) },
                "Welcome back,", name.ifBlank { "Driver" },
                scene = Scene.at(now), accent = Accent.forPaint(profile?.colourName.orEmpty()))
        )
        val theme = MediaItem.Builder().setMediaId(ID_THEME)
            .setUri("asset:///" + WelcomeSounds.assetPathForHour(themeOverride ?: ritual.theme, now.hour))
            .setMediaMetadata(meta(welcomeTitle(), "Welcome theme", art)).build()
        val loved = if (withTheme && dp != null && dp.lovedOne.playable && app.store.lovedOneFile(dp.id).exists())
            MediaItem.Builder().setMediaId(ID_LOVED_ONE).setUri(Uri.fromFile(app.store.lovedOneFile(dp.id)))
                .setMediaMetadata(meta(dp.lovedOne.label.ifBlank { "A message for you" }, "Recorded for you", art)).build()
        else null
        val lead = if (withTheme) listOfNotNull(theme, loved) else emptyList()

        if (!ritual.voice) return Futures.immediateFuture(lead.ifEmpty { listOf(theme) }.toMutableList())

        val drives = dp?.let { app.store.driveLog(it.id).all() }.orEmpty()
        val text = Briefing.text(profile, now.toLocalTime(), greeting = greeting, items = items,
            usualStop = DriveStats.usualStopNow(drives, System.currentTimeMillis())?.line(),
            streak = DriveStats.streak(drives, now.toLocalDate()))
        val tts = Briefing.synthesize(this, text)
        return Futures.transform(tts, { file ->
            val briefing = MediaItem.Builder().setMediaId(ID_BRIEFING_AUDIO).setUri(Uri.fromFile(file))
                .setMediaMetadata(meta("Your drive briefing", profile?.displayName ?: "My Drive", art)).build()
            val pause = if (lead.isNotEmpty() && ritual.delaySeconds > 0) {
                val f = File(cacheDir, "pause-${ritual.delaySeconds}.wav")
                if (!f.exists()) WelcomeSounds.writeSilence(f, ritual.delaySeconds)
                listOf(MediaItem.Builder().setMediaId(ID_DELAY).setUri(Uri.fromFile(f)).setMediaMetadata(meta("", "", art)).build())
            } else emptyList()
            (lead + pause + briefing).toMutableList()
        }, MoreExecutors.directExecutor())
    }

    /** Drives root: stats first (not playable), then recent drives. */
    private fun driveItems(): List<MediaItem> {
        val dp = app.store.active() ?: return listOf(info("none", "Recent drives appear here", ""))
        val drives = app.store.driveLog(dp.id).all()
        if (drives.isEmpty()) return listOf(info("none", "Recent drives appear here", "Your usual stops and streak build up as you drive"))
        val zone = ZoneId.systemDefault()
        val stats = buildList {
            add(info("stat-streak", "Streak: ${DriveStats.streak(drives, LocalDate.now(zone))} days", "Consecutive days with a drive"))
            add(info("stat-km", "Total distance: ${"%.0f".format(DriveStats.totalKm(drives))} km", "${drives.size} drives"))
            DriveStats.favouriteRoute(drives)?.let { add(info("stat-route", "Favourite route", "${it.from} → ${it.to} · ${it.count}x")) }
            DriveStats.usualStops(drives, zone).take(3).forEach { add(info("stat-stop-${it.label}", "Usual stop: ${it.label}", it.line())) }
        }
        val fmt = DateTimeFormatter.ofPattern("EEE d MMM, H:mm")
        val recent = drives.sortedByDescending { it.startTs }.take(10).map {
            info("drive-${it.id}", "${it.startLabel} → ${it.endLabel}",
                "${"%.1f".format(it.distanceKm)} km · ${Instant.ofEpochMilli(it.startTs).atZone(zone).format(fmt)}")
        }
        return stats + recent
    }

    private fun info(id: String, title: String, subtitle: String) = MediaItem.Builder().setMediaId(id).setMediaMetadata(
        MediaMetadata.Builder().setTitle(title).setArtist(subtitle).setIsPlayable(false).setIsBrowsable(false).build()
    ).build()

    private fun welcomeTitle(): String {
        val name = app.store.loadProfile()?.ownerName.orEmpty()
        return if (name.isBlank()) "Welcome back" else "Welcome back, $name"
    }


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
        const val ID_LOVED_ONE = "loved_one"; const val ID_DELAY = "delay"
    }
}
