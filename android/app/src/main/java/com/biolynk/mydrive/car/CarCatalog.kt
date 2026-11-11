package com.biolynk.mydrive.car

import org.json.JSONObject

/** Manufacturer colour options per model, from shared/car-catalog.json (copied into assets at build time). */
data class CarColour(val id: String, val name: String, val hex: String, val roof: String, val label: String)

data class CarModel(val make: String, val model: String, val note: String, val slug: String, val colours: List<CarColour>) {
    val title get() = "$make $model"
}

class CarCatalog(val models: List<CarModel>) {

    fun search(query: String): List<CarModel> {
        val q = query.trim().lowercase()
        if (q.isEmpty()) return models.take(12)
        return models.filter { it.title.lowercase().contains(q) }
    }

    fun find(slug: String) = models.firstOrNull { it.slug == slug }

    companion object {
        fun parse(json: String): CarCatalog {
            val root = JSONObject(json)
            val arr = root.getJSONArray("models")
            val models = (0 until arr.length()).map { i ->
                val m = arr.getJSONObject(i)
                val cs = m.getJSONArray("colours")
                CarModel(
                    make = m.getString("make"), model = m.getString("model"), note = m.optString("note"),
                    slug = m.getString("slug"),
                    colours = (0 until cs.length()).map { j ->
                        val c = cs.getJSONObject(j)
                        CarColour(c.getString("id"), c.getString("name"), c.getString("hex"),
                            c.getString("roof"), c.optString("label", c.getString("name")))
                    }
                )
            }
            return CarCatalog(models)
        }

        /** Asset path of the render for this car + colour (assets/cars/<slug>--<colourId>.jpg). */
        fun renderAsset(slug: String, colourId: String) = "cars/$slug--$colourId.jpg"
    }
}

data class CarProfile(
    val slug: String, val make: String, val model: String,
    val colourId: String, val colourName: String, val roof: String,
    val nickname: String, val ownerName: String,
) {
    val displayName get() = nickname.ifBlank { model }

    fun toJson(): String = JSONObject().apply {
        put("slug", slug); put("make", make); put("model", model)
        put("colourId", colourId); put("colourName", colourName); put("roof", roof)
        put("nickname", nickname); put("ownerName", ownerName)
    }.toString()

    companion object {
        fun fromJson(s: String) = JSONObject(s).let {
            CarProfile(it.getString("slug"), it.getString("make"), it.getString("model"),
                it.getString("colourId"), it.getString("colourName"), it.getString("roof"),
                it.optString("nickname"), it.optString("ownerName"))
        }
    }
}
