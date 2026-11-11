package com.biolynk.mydrive.ui

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import androidx.media3.common.MediaItem
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.biolynk.mydrive.MyDriveApp
import com.biolynk.mydrive.audio.ArtworkComposer
import com.biolynk.mydrive.audio.PlaybackService
import com.biolynk.mydrive.look.Accent
import com.biolynk.mydrive.look.Scene
import com.biolynk.mydrive.personal.DriveStats
import com.biolynk.mydrive.personal.DriverProfile
import com.biolynk.mydrive.personal.HomeStyle
import com.biolynk.mydrive.personal.ProfileBook
import java.time.LocalDate
import java.time.LocalDateTime
import com.biolynk.mydrive.car.CarColour
import com.biolynk.mydrive.car.CarModel
import com.biolynk.mydrive.car.CarProfile
import com.biolynk.mydrive.metrics.Metrics
import com.google.common.util.concurrent.MoreExecutors

val Gold = Color(0xFFD4B97E)
val Bg = Color(0xFF08090B)

class MainActivity : ComponentActivity() {
    private val app get() = application as MyDriveApp

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            var book by remember { mutableStateOf(app.store.book()) }
            var adding by remember { mutableStateOf(false) }
            val active = book.active
            val accent = Color(Accent.forPaint(active?.car?.colourName.orEmpty()))
            MaterialTheme(colorScheme = darkColorScheme(primary = accent, background = Bg, surface = Bg)) {
                Surface(Modifier.fillMaxSize(), color = Bg) {
                    if (active == null || adding) {
                        Onboarding(onCancel = if (active != null) ({ adding = false }) else null) { car ->
                            book = app.store.addProfile(car); adding = false
                        }
                    } else {
                        Home(book, onChange = { nb -> app.store.saveBook(nb); book = nb }, onPlay = ::playWelcome, onAdd = { adding = true })
                    }
                }
            }
        }
    }

    /** Phone-side test: same path Android Auto uses (MediaController -> PlaybackService). */
    private fun playWelcome() {
        app.metrics.markConnect(mapOf("via" to "phone_test"))
        val token = SessionToken(this, ComponentName(this, PlaybackService::class.java))
        val future = MediaController.Builder(this, token).buildAsync()
        future.addListener({
            val c = future.get()
            c.setMediaItem(MediaItem.Builder().setMediaId(PlaybackService.ID_WELCOME).build())
            c.prepare(); c.play()
        }, MoreExecutors.directExecutor())
    }
}

@Composable
fun Onboarding(onCancel: (() -> Unit)? = null, onDone: (CarProfile) -> Unit) {
    val app = MyDriveApp.instance
    var step by remember { mutableIntStateOf(0) }
    var query by remember { mutableStateOf("") }
    var model by remember { mutableStateOf<CarModel?>(null) }
    var colour by remember { mutableStateOf<CarColour?>(null) }
    var owner by remember { mutableStateOf("") }
    var nick by remember { mutableStateOf("") }
    LaunchedEffect(step) { app.metrics.log(Metrics.Event.ONBOARDING_STEP, mapOf("step" to "${step + 1}")) }

    Column(Modifier.fillMaxSize().padding(22.dp)) {
        Text("STEP ${step + 1} OF 3", color = Gold, fontSize = 11.sp, letterSpacing = 3.sp)
        onCancel?.let { TextButton(it) { Text("Cancel", color = Color.Gray) } }
        Spacer(Modifier.height(8.dp))
        when (step) {
            0 -> {
                Title("Which car do you drive?")
                OutlinedTextField(query, { query = it }, Modifier.fillMaxWidth(), placeholder = { Text("Search make or model") }, singleLine = true)
                LazyColumn(Modifier.weight(1f)) {
                    items(app.store.catalog.search(query)) { m ->
                        Row(Modifier.fillMaxWidth().clickable { model = m; colour = m.colours.first() }.padding(vertical = 14.dp),
                            verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(m.title, color = if (model == m) Color.White else Color.LightGray)
                                Text("${m.note} · ${m.colours.size} colours", color = Color.Gray, fontSize = 12.sp)
                            }
                            if (model == m) Box(Modifier.size(22.dp).clip(CircleShape).background(Gold))
                        }
                        HorizontalDivider(color = Color(0x14FFFFFF))
                    }
                }
            }
            1 -> {
                val m = model!!
                Title("What colour is it?")
                Text("${m.title} · official colours", color = Color.Gray, fontSize = 13.sp)
                Spacer(Modifier.height(14.dp))
                LazyVerticalGrid(GridCells.Fixed(4), Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    items(m.colours) { c -> Swatch(c, selected = colour == c) { colour = c } }
                }
                Text(colour?.label.orEmpty(), color = Gold, modifier = Modifier.padding(vertical = 10.dp))
            }
            else -> {
                val m = model!!; val c = colour!!
                Title("Meet your ${m.model}")
                app.store.carBitmap(m.slug, c.id)?.let {
                    Image(it.asImageBitmap(), null, Modifier.fillMaxWidth().height(200.dp).clip(RoundedCornerShape(16.dp)), contentScale = ContentScale.Crop)
                }
                Text(c.label, color = Color.Gray, fontSize = 13.sp, modifier = Modifier.padding(vertical = 10.dp))
                OutlinedTextField(owner, { owner = it }, Modifier.fillMaxWidth(), label = { Text("Your name (for the greeting)") }, singleLine = true)
                OutlinedTextField(nick, { nick = it }, Modifier.fillMaxWidth(), label = { Text("Call it") }, placeholder = { Text(m.model) }, singleLine = true)
                TextButton({ step = 1 }) { Text("Not quite right? Adjust", color = Color.Gray) }
                Spacer(Modifier.weight(1f))
            }
        }
        Button(
            onClick = {
                if (step < 2) step++ else {
                    val m = model!!; val c = colour!!
                    app.metrics.log(Metrics.Event.ONBOARDING_DONE, mapOf("model" to m.title, "colour" to c.id))
                    onDone(CarProfile(m.slug, m.make, m.model, c.id, c.name, c.roof, nick, owner))
                }
            },
            enabled = step != 0 || model != null,
            modifier = Modifier.fillMaxWidth().height(54.dp),
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Gold, contentColor = Color.Black)
        ) { Text(if (step == 2) "Looks right" else "Next", fontWeight = FontWeight.SemiBold) }
    }
}

@Composable
private fun Title(t: String) = Text(t, fontFamily = FontFamily.Serif, fontSize = 30.sp, color = Color.White,
    modifier = Modifier.padding(bottom = 12.dp))

@Composable
private fun Swatch(c: CarColour, selected: Boolean, onClick: () -> Unit) {
    val body = Color(android.graphics.Color.parseColor(c.hex))
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.clickable(onClick = onClick)) {
        Box(Modifier.size(46.dp).border(2.dp, if (selected) Gold else Color.Transparent, CircleShape).padding(4.dp).clip(CircleShape).background(body)) {
            if (c.roof != "body") Box(Modifier.fillMaxWidth().height(13.dp).background(Color(0xFF111111)))
        }
        Text(c.name, fontSize = 10.sp, maxLines = 2, color = if (selected) Gold else Color.Gray, lineHeight = 12.sp)
    }
}


@Composable
fun Home(book: ProfileBook, onChange: (ProfileBook) -> Unit, onPlay: () -> Unit, onAdd: () -> Unit) {
    val app = MyDriveApp.instance
    val p = book.active ?: return
    val accent = MaterialTheme.colorScheme.primary
    var log by remember { mutableStateOf(app.metrics.readAll()) }
    var welcome by remember { mutableStateOf(app.store.welcomeOnConnect) }
    var drives by remember(p.id) { mutableStateOf(app.store.driveLog(p.id).all()) }
    fun edit(f: (DriverProfile) -> DriverProfile) = onChange(book.updateActive(f))
    val now = LocalDateTime.now()
    val greeting = remember(p.id, now.hour) { app.store.greetings.pick(now.hour, p.car.ownerName, now.dayOfYear) }
    val art = remember(p.id, p.car.colourId, now.hour) {
        ArtworkComposer.compose(app.store.carBitmap(p.car.slug, p.car.colourId), "Welcome back,",
            p.car.ownerName.ifBlank { "Driver" }, side = 512, scene = Scene.at(now), accent = Accent.forPaint(p.car.colourName))
    }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(22.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        ProfileSwitcher(book, onSwitch = { id ->
            app.metrics.log(Metrics.Event.PROFILE_SWITCHED, mapOf("from" to (book.active?.id ?: ""), "to" to id))
            onChange(book.switchTo(id))
        }, onAdd = onAdd)

        if (p.style != HomeStyle.MINIMAL) {
            val h = if (p.style == HomeStyle.CAR_LARGE) 220.dp else 130.dp
            app.store.carBitmap(p.car.slug, p.car.colourId)?.let {
                Image(it.asImageBitmap(), null, Modifier.fillMaxWidth().height(h).clip(RoundedCornerShape(20.dp)), contentScale = ContentScale.Crop)
            }
        }
        Text(greeting, fontFamily = FontFamily.Serif, fontStyle = FontStyle.Italic, fontSize = 22.sp, color = Color.LightGray)
        Text(p.car.ownerName.ifBlank { "Driver" }, fontSize = if (p.style == HomeStyle.MINIMAL) 36.sp else 52.sp, fontWeight = FontWeight.Thin, color = Color.White)
        Text("${p.car.make} ${p.car.displayName} · ${p.car.colourName}", color = accent, fontSize = 13.sp)
        if (p.style == HomeStyle.STATS) {
            Text("${DriveStats.streak(drives, LocalDate.now())} day streak · ${"%.0f".format(DriveStats.totalKm(drives))} km · ${drives.size} drives",
                color = Color.White, fontSize = 15.sp)
            DriveStats.usualStopNow(drives, System.currentTimeMillis())?.let { Text(it.line(), color = accent, fontSize = 14.sp) }
        }
        Button(onPlay, Modifier.fillMaxWidth().height(54.dp), shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(containerColor = accent, contentColor = Color.Black)) { Text("Test welcome") }
        ToggleRow("Welcome when Android Auto connects", welcome) { welcome = it; app.store.welcomeOnConnect = it }

        SectionTitle("Look")
        StylePicker(p.style) { s -> edit { it.copy(style = s) } }

        BriefingItemsSection(p.items) { v -> edit { it.copy(items = v) } }
        LovedOneSection(p) { v -> edit { it.copy(lovedOne = v) } }
        RitualSection(p.ritual) { v -> edit { it.copy(ritual = v.normalised()) } }
        DrivesSection(drives, onAdd = { d -> app.store.driveLog(p.id).add(d); drives = app.store.driveLog(p.id).all() },
            onClear = { app.store.driveLog(p.id).clear(); drives = emptyList() })

        SectionTitle("Car screen artwork")
        Image(art.asImageBitmap(), null, Modifier.fillMaxWidth().aspectRatio(1f).clip(RoundedCornerShape(16.dp)))

        SectionTitle("Measurements")
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedButton({ log = app.metrics.readAll() }) { Text("Refresh") }
            OutlinedButton({ app.metrics.clear(); log = "" }) { Text("Clear") }
        }
        MonoLog(log.ifBlank { "No events yet" })
        TextButton({ onChange(book.remove(p.id)) }) { Text("Remove this car", color = Color(0xFFE57373)) }
    }
}
