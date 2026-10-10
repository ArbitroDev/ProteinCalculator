package arbitro.android.protein_calculator.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.lifecycle.compose.collectAsStateWithLifecycle

class MainActivity : ComponentActivity() {
    private val viewModel: WatchViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            WatchTheme {
                WatchApp(viewModel.screen.collectAsStateWithLifecycle().value)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // The phone may have changed the day while the watch app was away.
        viewModel.refresh()
    }
}
