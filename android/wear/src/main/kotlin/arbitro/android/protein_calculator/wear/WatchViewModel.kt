package arbitro.android.protein_calculator.wear

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import arbitro.android.protein_calculator.protocol.WatchProduct
import java.time.ZoneId
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
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

    /** A portion added on the watch, confirmed on the screen until [dismissAdded]. */
    data class Added(val product: WatchProduct, val phoneNearby: Boolean)

    private val _added = MutableStateFlow<Added?>(null)
    val added: StateFlow<Added?> = _added.asStateFlow()

    /** Asks the phone for the state of the day, if it is nearby, and sends it the waiting additions. */
    fun refresh() {
        viewModelScope.launch {
            phone.sync(store)
            if (store.pending().isNotEmpty()) SendWorker.schedule(getApplication())
        }
    }

    /**
     * Adds a portion of [product]: kept on the watch at once, then sent to
     * the phone, now or once it is nearby.
     */
    fun add(product: WatchProduct) {
        viewModelScope.launch {
            store.add(product, System.currentTimeMillis())
            SendWorker.schedule(getApplication())
            val nearby = (screen.value as? WatchScreen.Day)?.phoneNearby ?: false
            _added.value = Added(product, nearby)
        }
    }

    fun dismissAdded() {
        _added.value = null
    }
}
