package arbitro.android.protein_calculator.wear

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import java.time.ZoneId
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.shareIn
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class WatchViewModel(application: Application) : AndroidViewModel(application) {
    private val store = WatchStore(application)
    private val phone = PhoneLink(application)

    /**
     * The current time, again every half minute: the day may end, the state
     * gets older, the phone may come or go.
     */
    private val clock = flow {
        while (true) {
            emit(System.currentTimeMillis())
            delay(30_000)
        }
    }.shareIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), replay = 1)

    val screen: StateFlow<WatchScreen> =
        combine(store.saved, phone.phoneNearby(clock), clock) { saved, nearby, now ->
            watchScreenOf(saved, nearby, now, ZoneId.systemDefault())
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), WatchScreen.Loading)

    /** Asks the phone for the state of the day, if it is nearby. */
    fun refresh() {
        viewModelScope.launch { phone.sync(store) }
    }
}
