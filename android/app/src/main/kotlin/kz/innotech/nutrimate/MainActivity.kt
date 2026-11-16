package kz.innotech.nutrimate

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // CI screenshots only (tool/ci/android_smoke.sh): `adb shell setprop debug.nutrimate.shot fridge` opens a demo
    // screen (/shot/fridge — demo data in memory, nothing is saved). debug.* properties can be set only by adb / the
    // shell user, never by other apps; on normal phones the property is empty and nothing changes.
    override fun getInitialRoute(): String? {
        val shot = try {
            val p = Runtime.getRuntime().exec(arrayOf("getprop", "debug.nutrimate.shot"))
            p.inputStream.bufferedReader().use { it.readText() }.trim()
        } catch (e: Exception) {
            ""
        }
        if (shot.isNotEmpty() && shot != "none" && shot.matches(Regex("[a-z-]{1,32}"))) return "/shot/$shot"
        return super.getInitialRoute()
    }
}
