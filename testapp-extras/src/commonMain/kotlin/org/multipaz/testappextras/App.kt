package org.multipaz.testappextras

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.io.bytestring.ByteString
import multipazextras.testapp_extras.generated.resources.Res
import multipazextras.testapp_extras.generated.resources.back_button
import org.jetbrains.compose.resources.ExperimentalResourceApi
import org.jetbrains.compose.resources.stringResource
import org.jetbrains.compose.ui.tooling.preview.Preview
import org.multipaz.compose.prompt.PromptDialogs
import org.multipaz.prompt.PromptModel

import org.multipaz.util.Logger
import org.multipaz.facematch.FaceMatchLiteRtModel
import org.multipaz.testappextras.ui.AboutScreen
import org.multipaz.testappextras.ui.AppTheme
import org.multipaz.testappextras.ui.BarcodeScanningScreen
import org.multipaz.testappextras.ui.CameraScreen
import org.multipaz.testappextras.ui.FaceDetectionScreen
import org.multipaz.testappextras.ui.FaceMatchScreen
import org.multipaz.testappextras.ui.SelfieCheckScreen
import org.multipaz.testappextras.ui.StartScreen
import kotlin.time.Clock

/**
 * Application singleton.
 */
class App private constructor (val promptModel: PromptModel) {
    lateinit var faceMatchLiteRtModel: FaceMatchLiteRtModel
    private val initLock = Mutex()
    private var initialized = false

    suspend fun init() {
        initLock.withLock {
            if (initialized) {
                return
            }
            val initFuncs = listOf<Pair<suspend () -> Unit, String>>(
                Pair(::platformInit, "platformInit"),
                Pair(::faceMatchLiteRtModelInit, "faceMatchLiteRtModelInit")
            )

            val begin = Clock.System.now()
            for ((func, name) in initFuncs) {
                val funcBegin = Clock.System.now()
                func()
                val funcEnd = Clock.System.now()
                Logger.i(TAG, "$name initialization time: ${(funcEnd - funcBegin).inWholeMilliseconds} ms")
            }
            val end = Clock.System.now()
            Logger.i(TAG, "Total application initialization time: ${(end - begin).inWholeMilliseconds} ms")
            initialized = true
        }
    }

    @OptIn(ExperimentalResourceApi::class)
    private suspend fun faceMatchLiteRtModelInit() {
        val modelData = ByteString(*Res.readBytes("files/facenet_512.tflite"))
        faceMatchLiteRtModel = FaceMatchLiteRtModel(modelData, imageSquareSize = 160, embeddingsArraySize = 512)
    }

    companion object {
        private const val TAG = "App"

        private var app: App? = null
        fun getInstance(): App {
            if (app == null) {
                app = App(platformPromptModel)
            }
            return app!!
        }
    }

    private lateinit var snackbarHostState: SnackbarHostState

    @Composable
    @Preview
    fun Content(navController: NavHostController = rememberNavController()) {
        val isInitialized = remember { mutableStateOf<Boolean>(false) }
        if (!isInitialized.value) {
            CoroutineScope(Dispatchers.Main).launch {
                init()
                isInitialized.value = true
            }
            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(text = "Initializing...")
            }
            return
        }

        val backStackEntry by navController.currentBackStackEntryAsState()
        val routeWithoutArgs = backStackEntry?.destination?.route?.substringBefore('/')

        val currentDestination = appDestinations.find {
            it.route == routeWithoutArgs
        } ?: StartDestination

        snackbarHostState = remember { SnackbarHostState() }
        AppTheme {
            // A surface container using the 'background' color from the theme
            Scaffold(
                topBar = {
                    AppBar(
                        currentDestination = currentDestination,
                        canNavigateBack = navController.previousBackStackEntry != null,
                        navigateUp = { navController.navigateUp() },
                        includeSettingsIcon = false
                    )
                },
                snackbarHost = { SnackbarHost(hostState = snackbarHostState) },
            ) { innerPadding ->

                PromptDialogs(promptModel)

                NavHost(
                    navController = navController,
                    startDestination = StartDestination.route,
                    modifier = Modifier
                        .fillMaxSize()
                        //.verticalScroll(rememberScrollState())
                        .padding(innerPadding)
                ) {
                    composable(route = StartDestination.route) {
                        StartScreen(
                            onClickAbout = { navController.navigate(AboutDestination.route) },
                            onClickCamera = { navController.navigate(CameraDestination.route) },
                            onClickFaceDetection = { navController.navigate(FaceDetectionDestination.route) },
                            onClickBarcodeScanning = { navController.navigate(BarcodeScanningDestination.route) },
                            onClickSelfieCheck = { navController.navigate(SelfieCheckScreenDestination.route) },
                            onClickFaceMatch = { navController.navigate(FaceMatchScreenDestination.route) },
                        )
                    }
                    composable(route = AboutDestination.route) {
                        AboutScreen()
                    }
                    composable(route = CameraDestination.route) {
                        CameraScreen(
                            showToast = { message -> showToast(message) }
                        )
                    }
                    composable(route = FaceDetectionDestination.route) {
                        FaceDetectionScreen(
                            showToast = { message -> showToast(message) }
                        )
                    }
                    composable(route = FaceMatchScreenDestination.route) {
                        FaceMatchScreen(
                            faceMatchLiteRtModel = faceMatchLiteRtModel,
                            showToast = { message -> showToast(message) }
                        )
                    }
                    composable(route = SelfieCheckScreenDestination.route) {
                        SelfieCheckScreen(
                            showToast = { message -> showToast(message) }
                        )
                    }
                    composable(route = BarcodeScanningDestination.route) {
                        BarcodeScanningScreen(
                            showToast = { message -> showToast(message) }
                        )
                    }
                }
            }
        }
    }

    private fun showToast(message: String) {
        CoroutineScope(Dispatchers.Main).launch {
            when (snackbarHostState.showSnackbar(
                message = message,
                actionLabel = "OK",
                duration = SnackbarDuration.Short,
            )) {
                SnackbarResult.Dismissed -> {
                }

                SnackbarResult.ActionPerformed -> {
                }
            }
        }
    }
}

/**
 * Composable that displays the topBar and displays back button if back navigation is possible.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppBar(
    currentDestination: Destination,
    canNavigateBack: Boolean,
    navigateUp: () -> Unit,
    includeSettingsIcon: Boolean,
    modifier: Modifier = Modifier
) {
    val title = currentDestination.title?.let { stringResource(it) } ?: platformAppName
    TopAppBar(
        title = { Text(text = title) },
        colors = TopAppBarDefaults.mediumTopAppBarColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer
        ),
        modifier = modifier,
        navigationIcon = {
            if (canNavigateBack) {
                IconButton(onClick = navigateUp) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = stringResource(Res.string.back_button)
                    )
                }
            }
        },
        actions = {
            if (includeSettingsIcon) { // Placeholder for future settings icon.
                IconButton(onClick = {}) {
                    Icon(
                        imageVector = Icons.Filled.Settings,
                        contentDescription = null
                    )
                }
            }
        },
    )
}
