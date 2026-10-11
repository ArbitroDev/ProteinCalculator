package arbitro.android.protein_calculator.protocol

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

class WatchMessagesTest {
    private val state = DayState(
        day = 20261001,
        dayStartHour = 3,
        total = 32.5,
        goal = 140.0,
        entries = listOf(
            WatchEntry(id = 8, name = null, protein = 12.5, time = 1_790_000_000_000, fromWatch = true),
            WatchEntry(id = 5, name = "Oeufs", protein = 20.0, time = 1_789_990_000_000, fromWatch = false),
        ),
        products = listOf(
            WatchProduct(id = 4, name = "Skyr", protein = 15.0, favorite = true),
            WatchProduct(id = 2, name = "Whey", protein = 24.5, favorite = false),
        ),
        handled = listOf("a1"),
    )

    private val addition = WatchAddition(
        id = "a2",
        productId = 4,
        name = "Skyr",
        protein = 15.0,
        addedAt = 1_790_000_100_000,
    )

    private val deletion = WatchDeletion(id = "d1", entryId = 8, time = 1_790_000_000_000)

    private fun ByteArray.fields(): JsonObject = Json.parseToJsonElement(decodeToString()).jsonObject

    private fun JsonObject.bytes(): ByteArray = toString().encodeToByteArray()

    /** [message] with its field [name] set to [value]. */
    private fun ByteArray.with(name: String, value: JsonPrimitive): ByteArray =
        JsonObject(fields() + (name to value)).bytes()

    private fun Received<*>.value(): Any? = assertIs<Received.Message<*>>(this).value

    @Test
    fun `a state is read as it was written, with the version`() {
        val message = WatchMessages.encodeState(state)

        assertEquals(WatchProtocol.VERSION, message.fields()["v"]!!.jsonPrimitive.int)
        assertEquals(state, WatchMessages.decodeState(message).value())
    }

    @Test
    fun `a state without goal is read`() {
        val withoutGoal = state.copy(goal = null)

        assertEquals(withoutGoal, WatchMessages.decodeState(WatchMessages.encodeState(withoutGoal)).value())
    }

    @Test
    fun `a state keeps its first entries and products only`() {
        val entry = state.entries.first()
        val product = state.products.last()
        val long = state.copy(
            entries = List(WatchProtocol.MAX_ENTRIES + 5) { entry.copy(time = entry.time - it) },
            products = List(WatchProtocol.MAX_PRODUCTS + 5) { product.copy(id = it + 1L) },
        )

        val read = WatchMessages.decodeState(WatchMessages.encodeState(long)).value() as DayState

        assertEquals(long.entries.take(WatchProtocol.MAX_ENTRIES), read.entries)
        assertEquals(long.products.take(WatchProtocol.MAX_PRODUCTS), read.products)
    }

    @Test
    fun `a message of another version is not read`() {
        val message = WatchMessages.encodeState(state).with("v", JsonPrimitive(2))

        assertEquals(Received.OtherVersion(2), WatchMessages.decodeState(message))
        assertEquals(Received.OtherVersion(2), WatchMessages.decodeSyncRequest(message))
    }

    @Test
    fun `the answer to a message of another version lists the versions read`() {
        val answer = WatchMessages.encodeUnsupported()

        assertEquals("""{"unsupported":[1]}""", answer.decodeToString())
        assertEquals(Received.Unsupported(listOf(1)), WatchMessages.decodeState(answer))
        assertEquals(Received.Unsupported(listOf(1)), WatchMessages.decodeAddReply(answer))
    }

    @Test
    fun `what is not a message of the protocol is malformed`() {
        val message = WatchMessages.encodeState(state)
        for (bytes in listOf(
            "".encodeToByteArray(),
            "not json".encodeToByteArray(),
            "[1]".encodeToByteArray(),
            """{"day":20261001}""".encodeToByteArray(),
            """{"v":"one"}""".encodeToByteArray(),
            """{"v":1}""".encodeToByteArray(),
            """{"unsupported":1}""".encodeToByteArray(),
            message.with("total", JsonPrimitive("much")),
            JsonObject(message.fields() - "entries").bytes(),
        )) {
            assertEquals(Received.Malformed, WatchMessages.decodeState(bytes), bytes.decodeToString())
        }
    }

    @Test
    fun `a state of values out of their range is malformed`() {
        val entry = state.entries.first()
        val product = state.products.first()
        for (invalid in listOf(
            state.copy(day = 20260931),
            state.copy(day = 20261301),
            state.copy(day = 20250229),
            state.copy(dayStartHour = 8),
            state.copy(dayStartHour = -1),
            state.copy(total = -1.0),
            state.copy(goal = 0.0),
            state.copy(entries = listOf(entry.copy(id = 0))),
            state.copy(entries = listOf(entry.copy(name = " "))),
            state.copy(entries = listOf(entry.copy(protein = 0.0))),
            state.copy(entries = listOf(entry.copy(time = 0))),
            state.copy(products = listOf(product.copy(id = 0))),
            state.copy(products = listOf(product.copy(name = ""))),
            state.copy(products = listOf(product, product.copy(id = 5))),
            state.copy(handled = listOf("")),
            state.copy(handled = listOf("a".repeat(WatchProtocol.MAX_ID_LENGTH + 1))),
        )) {
            assertEquals(Received.Malformed, WatchMessages.decodeState(WatchMessages.encodeState(invalid)), "$invalid")
        }
    }

    @Test
    fun `a leap day is a day`() {
        val leapDay = state.copy(day = 20280229)

        assertEquals(leapDay, WatchMessages.decodeState(WatchMessages.encodeState(leapDay)).value())
    }

    @Test
    fun `a request for the state holds the version only`() {
        val request = WatchMessages.encodeSyncRequest()

        assertEquals("""{"v":1}""", request.decodeToString())
        assertEquals(Unit, WatchMessages.decodeSyncRequest(request).value())
    }

    @Test
    fun `additions are read as they were written`() {
        val additions = listOf(addition, addition.copy(id = "a3"))

        val read = WatchMessages.decodeAddRequest(WatchMessages.encodeAddRequest(additions)).value()

        assertEquals(AddRequest(additions), read)
    }

    @Test
    fun `a request of no addition or of too many is malformed`() {
        val tooMany = List(WatchProtocol.MAX_ADDITIONS + 1) { addition.copy(id = "a$it") }

        assertEquals(Received.Malformed, WatchMessages.decodeAddRequest(WatchMessages.encodeAddRequest(emptyList())))
        assertEquals(Received.Malformed, WatchMessages.decodeAddRequest(WatchMessages.encodeAddRequest(tooMany)))
        val most = tooMany.take(WatchProtocol.MAX_ADDITIONS)
        assertEquals(AddRequest(most), WatchMessages.decodeAddRequest(WatchMessages.encodeAddRequest(most)).value())
    }

    @Test
    fun `an invalid addition does not stop the others`() {
        val invalid = addition.copy(id = "a3", protein = -1.0)

        val read = WatchMessages.decodeAddRequest(WatchMessages.encodeAddRequest(listOf(addition, invalid))).value()

        assertEquals(listOf(true, false), (read as AddRequest).requests.map { it.isValid() })
    }

    @Test
    fun `an addition is valid with the values of a product only`() {
        assertEquals(true, addition.isValid())
        for (invalid in listOf(
            addition.copy(id = ""),
            addition.copy(id = "a".repeat(WatchProtocol.MAX_ID_LENGTH + 1)),
            addition.copy(productId = 0),
            addition.copy(name = "  "),
            addition.copy(protein = 0.0),
            addition.copy(protein = Double.NaN),
            addition.copy(addedAt = 0),
        )) {
            assertEquals(false, invalid.isValid(), "$invalid")
        }
    }

    @Test
    fun `an answer is read as it was written, its statuses in lowercase`() {
        val reply = AddReply(
            results = listOf(
                AddResult("a1", AddStatus.ADDED),
                AddResult("a2", AddStatus.DUPLICATE),
                AddResult("a3", AddStatus.INVALID),
            ),
            state = state,
        )
        val message = WatchMessages.encodeAddReply(reply)

        assertEquals(reply, WatchMessages.decodeAddReply(message).value())
        assertEquals(
            listOf("added", "duplicate", "invalid"),
            message.decodeToString().let { Regex(""""status":"(\w+)"""").findAll(it).map { match -> match.groupValues[1] }.toList() },
        )
    }

    @Test
    fun `an answer with an invalid state or id is malformed`() {
        val reply = AddReply(listOf(AddResult("a1", AddStatus.ADDED)), state)

        assertEquals(
            Received.Malformed,
            WatchMessages.decodeAddReply(WatchMessages.encodeAddReply(reply.copy(state = state.copy(dayStartHour = 9)))),
        )
        assertEquals(
            Received.Malformed,
            WatchMessages.decodeAddReply(WatchMessages.encodeAddReply(reply.copy(results = listOf(AddResult("", AddStatus.ADDED))))),
        )
    }

    @Test
    fun `an answer of an unknown status is malformed`() {
        val message = WatchMessages.encodeAddReply(AddReply(listOf(AddResult("a1", AddStatus.ADDED)), state))
            .decodeToString()
            .replace("\"added\"", "\"lost\"")
            .encodeToByteArray()

        assertEquals(Received.Malformed, WatchMessages.decodeAddReply(message))
    }

    @Test
    fun `deletions are read as they were written`() {
        val deletions = listOf(deletion, deletion.copy(id = "d2", entryId = 5))

        val read = WatchMessages.decodeDeleteRequest(WatchMessages.encodeDeleteRequest(deletions)).value()

        assertEquals(DeleteRequest(deletions), read)
    }

    @Test
    fun `a request of no deletion or of too many is malformed`() {
        val tooMany = List(WatchProtocol.MAX_DELETIONS + 1) { deletion.copy(id = "d$it") }

        assertEquals(Received.Malformed, WatchMessages.decodeDeleteRequest(WatchMessages.encodeDeleteRequest(emptyList())))
        assertEquals(Received.Malformed, WatchMessages.decodeDeleteRequest(WatchMessages.encodeDeleteRequest(tooMany)))
    }

    @Test
    fun `a deletion is valid with the id and time of an entry only`() {
        assertEquals(true, deletion.isValid())
        for (invalid in listOf(
            deletion.copy(id = ""),
            deletion.copy(id = "a".repeat(WatchProtocol.MAX_ID_LENGTH + 1)),
            deletion.copy(entryId = 0),
            deletion.copy(time = 0),
        )) {
            assertEquals(false, invalid.isValid(), "$invalid")
        }
    }

    @Test
    fun `a deletion is not read as an addition`() {
        val message = WatchMessages.encodeDeleteRequest(listOf(deletion))

        assertEquals(Received.Malformed, WatchMessages.decodeAddRequest(message))
    }

    @Test
    fun `an answer to deletions is read as it was written, its statuses in lowercase`() {
        val reply = DeleteReply(
            results = listOf(
                DeleteResult("d1", DeleteStatus.DELETED),
                DeleteResult("d2", DeleteStatus.DUPLICATE),
                DeleteResult("d3", DeleteStatus.MISSING),
                DeleteResult("d4", DeleteStatus.INVALID),
            ),
            state = state,
        )
        val message = WatchMessages.encodeDeleteReply(reply)

        assertEquals(reply, WatchMessages.decodeDeleteReply(message).value())
        assertEquals(
            listOf("deleted", "duplicate", "missing", "invalid"),
            message.decodeToString().let { Regex(""""status":"(\w+)"""").findAll(it).map { match -> match.groupValues[1] }.toList() },
        )
        assertEquals(
            Received.Malformed,
            WatchMessages.decodeDeleteReply(WatchMessages.encodeDeleteReply(reply.copy(state = state.copy(day = 0)))),
        )
    }

    @Test
    fun `the capability of the watch names the version`() {
        assertEquals("protein_calculator_watch_v1", WatchProtocol.watchCapability())
        assertEquals("protein_calculator_watch_v2", WatchProtocol.watchCapability(2))
    }
}
