package com.biolynk.mydrive.ui

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaPlayer
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.biolynk.mydrive.MyDriveApp
import com.biolynk.mydrive.audio.LovedOneRecorder
import com.biolynk.mydrive.personal.*
import java.time.LocalDate

@Composable
fun SectionTitle(t: String) =
    Text(t.uppercase(), color = MaterialTheme.colorScheme.primary, fontSize = 12.sp, letterSpacing = 2.sp,
        modifier = Modifier.padding(top = 10.dp))

@Composable
fun ToggleRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f), color = Color.White)
        Switch(checked, onChange)
    }
}

/** P4: switch between car + driver profiles. The active one is used in the car. */
@Composable
fun ProfileSwitcher(book: ProfileBook, onSwitch: (String) -> Unit, onAdd: () -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        book.profiles.forEach { p ->
            FilterChip(selected = p.id == book.active?.id, onClick = { onSwitch(p.id) },
                label = { Text(p.car.ownerName.ifBlank { p.car.displayName }.take(12) + " · " + p.car.displayName.take(10)) })
        }
        AssistChip(onClick = onAdd, label = { Text("+ Add car") })
    }
}

/** P6: phone home layout. */
@Composable
fun StylePicker(style: HomeStyle, onChange: (HomeStyle) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        HomeStyle.entries.forEach { s -> FilterChip(selected = s == style, onClick = { onChange(s) }, label = { Text(s.label) }) }
    }
}

/** P2: which lines the briefing may speak. */
@Composable
fun BriefingItemsSection(items: BriefingItems, onChange: (BriefingItems) -> Unit) {
    SectionTitle("Briefing")
    ToggleRow("Weather", items.weather) { onChange(items.copy(weather = it)) }
    ToggleRow("First calendar event", items.calendar) { onChange(items.copy(calendar = it)) }
    ToggleRow("Traffic ETA", items.traffic) { onChange(items.copy(traffic = it)) }
    ToggleRow("Usual stop", items.usualStop) { onChange(items.copy(usualStop = it)) }
    ToggleRow("Streak", items.streak) { onChange(items.copy(streak = it)) }
}

/** P2: the loved-one line. Recording happens here on the phone only; the mic is asked for on tapping Record. */
@Composable
fun LovedOneSection(p: DriverProfile, onChange: (LovedOne) -> Unit) {
    val ctx = LocalContext.current
    val app = MyDriveApp.instance
    val file = remember(p.id) { app.store.lovedOneFile(p.id) }
    val recorder = remember { LovedOneRecorder(ctx) }
    var recording by remember { mutableStateOf(false) }
    var note by remember { mutableStateOf("") }
    DisposableEffect(p.id) { onDispose { if (recorder.isRecording) recorder.stop() } }

    fun begin() {
        recording = recorder.start(file) { recording = false; onChange(p.lovedOne.copy(hasClip = file.exists() && file.length() > 0, enabled = true)); note = "Saved (15 s limit reached)" }
        note = if (recording) "Recording… up to ${LovedOne.MAX_SECONDS} seconds" else "Could not start the microphone"
    }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) begin() else note = "Microphone permission is needed to record"
    }

    SectionTitle("Loved-one line")
    var label by remember(p.id) { mutableStateOf(p.lovedOne.label) } // local state so fast typing is never dropped
    OutlinedTextField(label, { label = it.take(24); onChange(p.lovedOne.copy(label = label)) }, Modifier.fillMaxWidth(),
        label = { Text("Label, e.g. Papa") }, singleLine = true)
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        if (!recording) {
            OutlinedButton({
                if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) begin()
                else ask.launch(Manifest.permission.RECORD_AUDIO)
            }) { Text(if (p.lovedOne.hasClip) "Re-record" else "Record") }
        } else {
            Button({
                val ok = recorder.stop(); recording = false
                note = if (ok) "Saved" else "Too short, nothing saved"
                onChange(p.lovedOne.copy(hasClip = ok || p.lovedOne.hasClip && file.exists(), enabled = ok || p.lovedOne.enabled))
            }) { Text("Stop") }
        }
        if (p.lovedOne.hasClip && !recording) OutlinedButton({
            runCatching { MediaPlayer().apply { setDataSource(file.path); prepare(); setOnCompletionListener { it.release() }; start() } }
        }) { Text("Play") }
        if (p.lovedOne.hasClip && !recording) TextButton({ file.delete(); onChange(p.lovedOne.copy(hasClip = false, enabled = false)); note = "Deleted" }) { Text("Delete") }
    }
    if (note.isNotEmpty()) Text(note, color = Color.Gray, fontSize = 12.sp)
    ToggleRow("Play after the welcome sound", p.lovedOne.enabled && p.lovedOne.hasClip) { on ->
        if (p.lovedOne.hasClip) onChange(p.lovedOne.copy(enabled = on)) else note = "Record a clip first"
    }
}

/** P4: the ritual. */
@Composable
fun RitualSection(r: RitualSettings, onChange: (RitualSettings) -> Unit) {
    SectionTitle("Ritual")
    Text("Welcome sound", color = Color.Gray, fontSize = 12.sp)
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        WelcomeSounds.THEMES.forEach { t ->
            FilterChip(selected = t == r.theme, onClick = { onChange(r.copy(theme = t)) }, label = { Text(t.replaceFirstChar(Char::uppercase)) })
        }
    }
    Text("Pause before the briefing: ${r.delaySeconds} s", color = Color.Gray, fontSize = 12.sp)
    Slider(r.delaySeconds.toFloat(), { onChange(r.copy(delaySeconds = it.toInt())) },
        valueRange = RitualSettings.MIN_DELAY.toFloat()..RitualSettings.MAX_DELAY.toFloat(), steps = RitualSettings.MAX_DELAY - 1)
    ToggleRow("Spoken briefing (voice)", r.voice) { onChange(r.copy(voice = it)) }
}

/** P3: stats from the drive log + debug buttons to simulate drives (no location permission in this build). */
@Composable
fun DrivesSection(drives: List<Drive>, onAdd: (Drive) -> Unit, onClear: () -> Unit) {
    SectionTitle("Drives")
    val today = LocalDate.now()
    Text("Streak ${DriveStats.streak(drives, today)} days · ${"%.0f".format(DriveStats.totalKm(drives))} km · ${drives.size} drives",
        color = Color.White, fontSize = 14.sp)
    DriveStats.favouriteRoute(drives)?.let { Text("Favourite route: ${it.from} → ${it.to} (${it.count}x)", color = Color.Gray, fontSize = 13.sp) }
    DriveStats.usualStops(drives).forEach { Text("Usual stop: ${it.line()}", color = Color.Gray, fontSize = 13.sp) }
    Text("Drives are stored on this phone only. Real capture is not switched on in this build.", color = Color.DarkGray, fontSize = 11.sp)
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        OutlinedButton({
            val now = System.currentTimeMillis()
            val labels = listOf("Home" to "Clinic", "Clinic" to "Home", "Home" to "Office", "Office" to "Gym")
            val (a, b) = labels[drives.size % labels.size]
            onAdd(Drive("sim-$now", now - 35 * 60_000L, now, 12.4, a, b))
        }) { Text("Add drive") }
        OutlinedButton({
            val now = System.currentTimeMillis()
            val hour = java.time.LocalTime.now().hour
            (0..6).forEach { d -> onAdd(DriveStats.simulated(now, d, hour, "Home", "Clinic", 14.2, 32)) }
        }) { Text("Seed a week") }
        TextButton(onClear) { Text("Clear", color = Color(0xFFE57373), maxLines = 1, softWrap = false) }
    }
}

@Composable
fun MonoLog(text: String) = Text(text, fontFamily = FontFamily.Monospace, fontSize = 10.sp, color = Color.Gray)
