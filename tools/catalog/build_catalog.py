"""Builds shared/car-catalog.json: India-market models with manufacturer colour names.

Source: manufacturer colour lists as published on CarDekho colour pages (official sites blocked bots),
collected 11 Nov 2026. BMW X1 from bmw.in. Hex values are approximations for swatches only.
Roof: "body" = single tone, otherwise the roof colour of the dual-tone option.
Re-run after editing DATA:  python tools/catalog/build_catalog.py
"""
import json, pathlib, re

SRC = "https://www.cardekho.com/{make}/{model}/colors"

# make | model | note | slug-on-cardekho ; colours "Name,#hex,roof; ..."
DATA = """
Jeep|Meridian|7-seater SUV|jeep/meridian|Galaxy Blue,#1F3A5F,body;Pearl White,#F2F2F0,body;Brilliant Black,#0B0B0C,body;Minimal Grey,#6E7173,body;Techno Metallic Green,#3E5A4A,body;Velvet Red,#7A1F2B,body;Silvery Moon,#B9BCBF,body;Magnesio Grey,#5A5C5E,body
Jeep|Compass|5-seater SUV|jeep/compass|Grigio Magnesio,#383838,body;Galaxy Blue,#1F3A5F,body;Pearl White,#F2F2F0,body;Brilliant Black,#0B0B0C,body;Exotica Red,#8A1C24,body;Techno Metallic Green,#3E5A4A,body;Silvery Moon,#B9BCBF,body
Mahindra|XUV700|SUV|mahindra/xuv700|Everest White,#E3E5E9,body;Everest White,#E3E5E9,black;Valyrian Silver,#A9ADB1,body;Valyrian Silver,#878C90,black;Stealth Black,#111214,body;Midnight Black,#1B1D22,body;Midnight Black,#1B1D22,black;Deep Forest,#2E4A3A,body;Burnt Sienna,#8B4A2B,body
Mahindra|Scorpio-N|SUV|mahindra/scorpio-n|Everest White,#D1D3D5,body;Galaxy Grey,#3A3B3F,body;Oceanic,#2F5C6E,body;Stealth Black,#111214,body;Deep Forest,#2E4A3A,body
Mahindra|Thar Roxx|SUV|mahindra/thar-roxx|Everest White,#EAEBEE,body;Stealth Black,#0E0F0B,body;Nebula Blue,#1F3550,body;Battleship Grey,#5B5F63,body;Deep Forest,#2E4A3A,body;Tango Red,#B3262E,body;Burnt Sienna,#8B4A2B,body;Citrine Yellow,#D9B93A,body
Mahindra|XEV 9e|Electric SUV|mahindra/xev-9e|Everest White,#F5F5F5,body;Satin White,#EEEEEB,body;Desert Myst,#B8AE9C,body;Satin Desert Myst,#C0BEB7,body;Ruby Velvet,#8A2C36,body;Stealth Black,#111214,body;Satin Black,#1A1A1C,body;Nebula Blue,#1F3550,body;Deep Forest,#2E4A3A,body;Tango Red,#B3262E,body
Mahindra|BE 6|Electric SUV|mahindra/be-6|Everest White,#E3E5E9,body;Everest White Satin,#E3E5E9,body;Ruby Velvet,#8A4245,body;Graphite Storm,#4A4D52,body;Stealth Black,#111214,body;Satin Black,#1A1A1C,body;Desert Myst,#B8AE9C,body;Firestorm Orange,#E0622B,body;Firestorm Orange Satin,#E0622B,body;Rosso Impulso Satin,#A3262E,body;Deep Forest,#2E4A3A,body;Tango Red,#B3262E,body
Tata|Harrier|SUV|tata/harrier|Pristine White,#F4F4F2,body;Pristine White,#F4F4F2,black;Nitro Crimson,#841E33,black;Seaweed Green,#556034,body;Seaweed Green,#556034,black;Sunlit Yellow,#E0B43A,black;Fearless Red,#B3262E,body;Fearless Red,#B3262E,black;Daytona Grey,#6B6E70,body;Daytona Grey,#6B6E70,black;Pure Grey,#8A8D90,body;Pure Grey,#8A8D90,black;Oberon Black,#0B0B0C,body;Matte Stealth Black,#15161A,body
Tata|Safari|7-seater SUV|tata/safari|Frost White,#F2F2F0,body;Frost White,#F2F2F0,black;Cosmic Gold,#B08D57,body;Cosmic Gold,#B08D57,black;Supernova Copper,#9C5B3A,body;Supernova Copper,#9C5B3A,black;Royal Blue,#1F3A6B,body;Royal Blue,#1F3A6B,black;Pure Grey,#676767,body;Pure Grey,#676767,black;Daytona Grey,#6B6E70,body;Daytona Grey,#6B6E70,black;Oberon Black,#0B0B0C,body;Matte Stealth Black,#15161A,body
Tata|Nexon|Compact SUV|tata/nexon|Pristine White,#F4F4F2,body;Pristine White,#F4F4F2,black;Ocean Blue,#203B42,body;Ocean Blue,#203B42,white;Grassland Beige,#B8A88A,body;Grassland Beige,#B8A88A,black;Royal Blue,#1F3A6B,body;Royal Blue,#1F3A6B,black;Pure Grey,#8A8D90,body;Pure Grey,#626262,black;Daytona Grey,#6B6E70,body;Daytona Grey,#6B6E70,black;Munnar Mist,#8C9A8A,black;Coorg Clouds,#8E9399,black;Atlas Black,#1B1D22,body
Tata|Curvv|Coupe SUV|tata/curvv|Pristine White,#F4F4F2,black;Opera Blue,#0061AA,black;Pure Grey,#8A8D90,black;Nitro Crimson,#841E33,black;Glossy Carbon Black,#15161A,body
Hyundai|Creta|SUV|hyundai/creta|Atlas White,#F4F4F2,body;Atlas White,#F4F4F2,Titanium Black;Robust Emerald Pearl,#1F4A3C,body;Starry Night,#1C2230,body;Ecotronic Grey,#7A7D82,body;Ecotronic Grey Matte,#6B6E73,body;Titanium Black,#1C1D21,body;Titanium Black Matte,#2B2D31,body
Hyundai|Alcazar|7-seater SUV|hyundai/alcazar|Atlas White,#F4F4F2,body;Atlas White,#F4F4F2,black;Robust Emerald Pearl,#1F4A3C,body;Robust Emerald Matte,#2A4F42,body;Starry Night,#1C2230,body;Golden Bronze,#8A6A3B,body;Titanium Black,#1C1D21,body;Titanium Black Matte,#26282C,body
Hyundai|Verna|Sedan|hyundai/verna|Atlas White,#F4F4F2,body;Atlas White,#F4F4F2,black;Starry Night,#1C2230,body;Titan Grey,#7D8084,body;Titan Grey Matte,#5E6166,body;Classy Blue,#2F4A6B,body;Titanium Black,#1C1D21,body
Kia|Seltos|SUV|kia/seltos|Glacier White Pearl,#EEF0F2,body;Glacier White Pearl,#EEF0F2,Aurora Black Pearl;Clear White,#F5F5F5,body;Ivory Silver Gloss,#D9D6CC,body;Morning Haze,#C9CBCD,body;Gravity Grey,#6E7175,body;Matte Graphite,#4A4D52,body;Pewter Olive,#5A5A45,body;Frost Blue,#8FB3CC,body;Imperial Blue,#1F3A6B,body;Magma Red,#A3262C,body;Magma Red,#A3262C,Aurora Black Pearl;Aurora Black Pearl,#0E0F12,body
Kia|Carens|MPV|kia/carens|Clear White,#F5F5F5,body;Sparkling Silver,#B9BCC0,body;Gravity Grey,#6E7175,body;Pewter Olive,#5A5A45,body;Imperial Blue,#1F3A6B,body;Aurora Black Pearl,#0E0F12,body
Kia|Sonet|Compact SUV|kia/sonet|Glacier White Pearl,#EEF0F2,body;Glacier White Pearl,#EEF0F2,Aurora Black Pearl;Clear White,#F5F5F5,body;Gravity Grey,#6E7175,body;Matte Graphite,#4A4D52,body;Pewter Olive,#5A5A45,body;Imperial Blue,#1F3A6B,body;Magma Red,#A3262C,body;Magma Red,#A3262C,Aurora Black Pearl;Aurora Black Pearl,#0E0F12,body
Maruti Suzuki|Grand Vitara|SUV|maruti/grand-vitara|Arctic White,#F4F4F2,body;Arctic White,#F4F4F2,black;Splendid Silver,#B5B8BC,body;Splendid Silver,#B5B8BC,black;Grandeur Grey,#6E7175,body;Nexa Blue,#1E3F6E,body;Opulent Red,#8E1B25,body;Opulent Red,#8E1B25,black;Chestnut Brown,#5C3A26,body;Midnight Black,#1A1B1F,body
Maruti Suzuki|Brezza|Compact SUV|maruti/brezza|Pearl Arctic White,#F4F4F2,body;Pearl Arctic White,#F4F4F2,Bluish Black;Splendid Silver,#B5B8BC,body;Magma Grey,#5A5D62,body;Lustrous Beige,#C8B49A,body;Lustrous Beige,#C8B49A,Bluish Black;Sizzling Red,#B32020,Bluish Black;Vivacious Orange,#D9622B,body;Pearl Bluish Black,#1E2530,body
Maruti Suzuki|Swift|Hatchback|maruti/swift|Pearl Arctic White,#F4F4F2,body;Pearl Arctic White,#F4F4F2,Bluish Black;Splendid Silver,#B5B8BC,body;Magma Grey,#5A5D62,body;Luster Blue,#2E5C8A,body;Luster Blue,#2E5C8A,Bluish Black;Sizzling Red,#B32020,body;Sizzling Red,#B32020,Bluish Black;Novel Orange,#E0702A,body;Bluish Black,#1E2530,body
Maruti Suzuki|Baleno|Hatchback|maruti/baleno|Arctic White,#F4F4F2,body;Splendid Silver,#B5B8BC,body;Grandeur Grey,#6E7175,body;Nexa Blue,#1E3F6E,body;Enigmatic Teal Green,#1F5A5A,body;Opulent Red,#8E1B25,body;Bluish Black,#1E2530,body
Maruti Suzuki|Dzire|Sedan|maruti/dzire|Pearl Arctic White,#F4F4F2,body;Splendid Silver,#B5B8BC,body;Magma Grey,#5A5D62,body;Alluring Blue,#2F5F8F,body;Gallant Red,#A32A2A,body;Nutmeg Brown,#6B4A32,body;Bluish Black,#1E2530,body
Maruti Suzuki|Ertiga|MPV|maruti/ertiga|Arctic White,#F4F4F2,body;Splendid Silver,#B5B8BC,body;Magma Grey,#5A5D62,body;Prime Oxford Blue,#1F3560,body;Auburn Red,#7A2A2A,body;Pearl Metallic Dignity Brown,#5B3D2B,body;Bluish Black,#1E2530,body
Toyota|Fortuner|7-seater SUV|toyota/fortuner|Super White,#F5F5F5,body;Platinum White Pearl,#D9DCE2,body;Avant Garde Bronze,#5A4A3F,body;Sparkling Black Crystal Shine,#2F2C2F,body;Attitude Black,#0B0B0C,body
Toyota|Innova Hycross|MPV|toyota/innova-hycross|Super White,#F4F4F4,body;Platinum White Pearl,#E2E2E0,body;Silver Metallic,#A5A9AD,body;Avant Garde Bronze,#6B5B4E,body;Blackish Ageha Glass Flake,#2A2D33,body;Attitude Black Mica,#0B0A0A,body
Toyota|Urban Cruiser Hyryder|SUV|toyota/urban-cruiser-hyryder|Cafe White,#E8DFD0,body;Cafe White,#E8DFD0,black;Enticing Silver,#9A9CA0,body;Enticing Silver,#9A9CA0,black;Gaming Grey,#6E7174,body;Speedy Blue,#113761,body;Speedy Blue,#113761,black;Sportin Red,#B3262E,body;Sportin Red,#B3262E,black;Cave Black,#1A1A1C,body;Midnight Black,#0E0E10,body
Honda|City|Sedan|honda/city|Platinum White Pearl,#E3E3EA,body;Lunar Silver Metallic,#A0A0A8,body;Meteoroid Grey Metallic,#5E6165,body;Obsidian Blue Pearl,#1F2A44,body;Radiant Red Metallic,#A3132B,body;Crystal Black Pearl,#0E0E10,body
Honda|Elevate|SUV|honda/elevate|Platinum White Pearl,#D9DBDF,body;Platinum White Pearl,#D9DBDF,black;Lunar Silver Metallic,#9A9EA1,body;Meteoroid Grey Metallic,#5E6165,body;Obsidian Blue Pearl,#1F2A44,body;Radiant Red Metallic,#A3132B,body;Radiant Red Metallic,#A3132B,black;Nordic Forest Pearl,#2F4A3A,body;Nordic Forest Pearl,#2F4A3A,black;Crystal Black Pearl,#0E0E10,body
Skoda|Kylaq|Compact SUV|skoda/kylaq|Candy White,#F4F4F2,body;Brilliant Silver,#A8A9AD,body;Steel Grey,#6B7075,body;Carbon Steel,#4A4D52,body;Lava Blue,#295773,body;Cherry Red,#9E1B2A,body;Deep Black,#0B0B0C,body
Skoda|Kushaq|SUV|skoda/kushaq|Candy White,#F4F4F2,body;Brilliant Silver,#A8A9AD,body;Steel Grey,#6B7075,body;Carbon Steel,#4A4D52,body;Lava Blue,#163550,body;Shimla Green,#4F6B4E,body;Cherry Red,#9E1B2A,body;Deep Black,#0B0B0C,body
Skoda|Slavia|Sedan|skoda/slavia|Candy White,#F4F4F2,body;Arctic Silver,#D5D8DC,body;Brilliant Silver,#A8A9AD,body;Steel Grey,#6B7075,body;Carbon Steel,#4A4D52,body;Cappuccino Beige,#B8A590,body;Lava Blue,#1E3140,body;Shimla Green,#4F6B4E,body;Cherry Red,#9E1B2A,body;Deep Black,#0B0B0C,body
Volkswagen|Taigun|SUV|volkswagen/taigun|Candy White,#F4F4F2,body;Reflex Silver Metallic,#B5B9BE,body;Steel Grey,#6B7075,body;Carbon Steel Grey Metallic,#5E6165,body;Carbon Steel Matte,#4A4D52,body;Lava Blue Metallic,#0E2839,body;Avocado Pearl Effect,#5E6B4A,body;Wild Cherry Red Metallic,#531622,body;Deep Black Pearl,#0B0B0C,body
Volkswagen|Virtus|Sedan|volkswagen/virtus|Candy White,#F4F4F2,body;Reflex Silver,#B5B9BE,body;Carbon Steel Grey,#5E6165,body;Carbon Steel Grey Matte,#36383C,body;Lava Blue,#043C69,body;Rising Blue Metallic,#3F5A7A,body;Avocado Pearl,#5E6B4A,body;Wild Cherry Red,#531622,body;Deep Black Pearl,#0B0B0C,body
MG|Hector|SUV|mg/hector|Pearl White,#E6E6E6,body;Aurora Silver,#A7AAAE,body;Celadon Blue,#7FA3B5,body;Glaze Red,#8E1B2C,body;Starry Black,#101012,body
MG|Windsor EV|Electric|mg/windsor-ev|Pearl White,#E6E6E6,body;Aurora Silver,#A7AAAE,body;Turquoise Green,#3E8C86,body;Celadon Blue,#7FA3B5,body;Glaze Red,#8E1B2C,body;Starry Black,#000000,body
BMW|X1|Luxury SUV|bmw/x1|Mineral White Metallic,#E9E9E9,body;Skyscraper Grey Metallic,#3C4343,body;Night Dusk Blue,#1C2A3F,body;M Carbon Black Metallic,#1A1A1C,body
BMW|3 Series Gran Limousine|Luxury sedan|bmw/3-series-long-wheelbase|Mineral White,#CDCDCB,body;Skyscraper Grey Metallic,#3C4343,body;Portimao Blue,#1F3A5C,body;Carbon Black,#1C212D,body
Mercedes-Benz|GLA|Luxury SUV|mercedes-benz/gla|Polar White,#F4F4F2,body;Iridium Silver,#A0A8AC,body;Mountain Grey,#545755,body;Cosmos Black,#0D0E10,body
Mercedes-Benz|C-Class|Luxury sedan|mercedes-benz/c-class|Opalite White Bright,#F2F1EC,body;High Tech Silver,#A0A7AE,body;Selenite Grey,#5C6062,body;Sodalite Blue,#2A3D5C,body;Obsidian Black,#101114,body
Audi|Q3|Luxury SUV|audi/q3|Glacier White Metallic,#E6E8EA,body;Nano Grey Metallic,#33342F,body;Navarra Blue Metallic,#1D2F4F,body;Progressive Red Metallic,#8F1D24,body;Mythos Black Metallic,#15120D,body
"""

OFFICIAL = {"BMW|X1": "https://www.bmw.in/en/all-models/x-series/X1/bmw-x1-highlights.html"}
NOTES = {"Mahindra|XUV700": "Replaced by XUV 7XO in 2026; kept for existing owners."}


def slug(s): return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def main():
    models = []
    for line in DATA.strip().splitlines():
        make, model, note, cd, cols = line.split("|")
        colours = []
        for c in cols.split(";"):
            name, hexv, roof = [x.strip() for x in c.split(",")]
            roof = "body" if roof == "body" else roof
            cid = slug(name) + ("" if roof == "body" else "-" + slug(roof) + "-roof")
            colours.append({"id": cid, "name": name, "hex": hexv, "roof": roof,
                            "label": name if roof == "body" else f"{name} · {roof.lower()} roof"})
        key = f"{make}|{model}"
        models.append({"make": make, "model": model, "note": note, "slug": slug(f"{make} {model}"),
                       "source": OFFICIAL.get(key, SRC.format(make=cd.split('/')[0], model=cd.split('/')[1])),
                       "remark": NOTES.get(key, ""), "colours": colours})
    out = {"version": 2, "collected": "2026-11-11", "market": "IN", "models": models}
    root = pathlib.Path(__file__).resolve().parents[2]
    (root / "shared" / "car-catalog.json").write_text(json.dumps(out, indent=1, ensure_ascii=False))
    n = sum(len(m["colours"]) for m in models)
    print(f"{len(models)} models, {n} colour options")


if __name__ == "__main__":
    main()
