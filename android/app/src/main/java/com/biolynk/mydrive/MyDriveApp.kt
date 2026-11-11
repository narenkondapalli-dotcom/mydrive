package com.biolynk.mydrive

import android.app.Application
import androidx.car.app.connection.CarConnection
import com.biolynk.mydrive.data.Store
import com.biolynk.mydrive.metrics.Metrics
import java.io.File

class MyDriveApp : Application() {
    lateinit var metrics: Metrics; private set
    lateinit var store: Store; private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        metrics = Metrics(File(filesDir, "metrics.jsonl"), build = BuildConfigLite.VERSION_CODE)
        store = Store(this)
        metrics.log(Metrics.Event.APP_LAUNCHED, mapOf("surface" to "phone_process"))

        // Detect Android Auto projection. The welcome itself starts when Android Auto binds to
        // PlaybackService (onPlaybackResumption / first browse), so no background-start tricks are needed.
        CarConnection(this).type.observeForever { type ->
            if (type == CarConnection.CONNECTION_TYPE_PROJECTION) {
                metrics.markConnect(mapOf("type" to "projection"))
            }
        }
    }

    companion object {
        lateinit var instance: MyDriveApp; private set
    }
}

/** Avoids enabling the BuildConfig feature just for the version code. */
object BuildConfigLite { const val VERSION_CODE = "1" }
