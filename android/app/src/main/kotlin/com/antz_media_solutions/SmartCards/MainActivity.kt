package com.antz_media_solutions.SmartCards

import android.app.DownloadManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.provider.ContactsContract.CommonDataKinds.Photo
import android.provider.ContactsContract.Data
import android.provider.ContactsContract.RawContacts
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val NATIVE_CONTACTS_CHANNEL = "com.smartcard/native_contacts_helper"
        private const val DOWNLOAD_CHANNEL_ID = "smartcard_downloads"
        private val THIRD_PARTY_SYNC_ACCOUNTS = setOf(
            "com.whatsapp",
            "org.telegram.messenger",
            "org.telegram.messenger.web",
            "com.facebook.orca",
            "com.viber.voip",
            "com.truecaller",
            "com.skype.raider",
        )
    }

    private val contactPhotoExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_CONTACTS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "writeContactPhoto" -> {
                        val contactId = call.argument<String>("contactId")
                        val photoBytes = call.argument<ByteArray>("photoBytes")
                        val thumbBytes = call.argument<ByteArray>("thumbnailBytes")
                        if (contactId.isNullOrBlank() || photoBytes == null || photoBytes.isEmpty()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        contactPhotoExecutor.execute {
                            val updated = writePhotoToWritableRawContacts(
                                contactId = contactId,
                                photoBytes = photoBytes,
                                thumbBytes = if (thumbBytes != null && thumbBytes.isNotEmpty()) thumbBytes else photoBytes,
                            )
                            runOnUiThread { result.success(updated) }
                        }
                    }
                    "notifyDownloadComplete" -> {
                        val filePath = call.argument<String>("filePath")
                        val fileName = call.argument<String>("fileName") ?: "Download"
                        val mimeType = call.argument<String>("mimeType") ?: "image/*"
                        if (filePath.isNullOrBlank()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        showDownloadStatusNotification(filePath, fileName, mimeType)
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun showDownloadStatusNotification(filePath: String, fileName: String, mimeType: String) {
        try {
            val file = File(filePath)
            // 1. Tell MediaScanner so Google Photos/Gallery lists it immediately
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(file.absolutePath),
                arrayOf(mimeType),
                null
            )

            // 2. Post native status bar notification with download complete icon
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    DOWNLOAD_CHANNEL_ID,
                    "Downloads",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "Download notifications"
                    setShowBadge(true)
                }
                notificationManager.createNotificationChannel(channel)
            }

            val fileUri = try {
                FileProvider.getUriForFile(
                    applicationContext,
                    "${applicationContext.packageName}.flutter.share_provider",
                    file
                )
            } catch (_: Throwable) {
                Uri.fromFile(file)
            }

            val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(fileUri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            val pendingIntent = PendingIntent.getActivity(
                applicationContext,
                System.currentTimeMillis().toInt(),
                viewIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )

            val builder = NotificationCompat.Builder(applicationContext, DOWNLOAD_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_sys_download_done)
                .setContentTitle(fileName)
                .setContentText("Download complete")
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)

            notificationManager.notify((System.currentTimeMillis() % 100000).toInt(), builder.build())

            // 3. Also notify Android DownloadManager
            try {
                val dm = getSystemService(Context.DOWNLOAD_SERVICE) as? DownloadManager
                dm?.addCompletedDownload(
                    fileName,
                    "Download complete",
                    true,
                    mimeType,
                    file.absolutePath,
                    file.length(),
                    false
                )
            } catch (_: Throwable) {}
        } catch (_: Throwable) {}
    }

    override fun onDestroy() {
        contactPhotoExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun writePhotoToWritableRawContacts(
        contactId: String,
        photoBytes: ByteArray,
        thumbBytes: ByteArray,
    ): Boolean {
        val resolver = applicationContext.contentResolver
        val googleRawIds = mutableListOf<Long>()
        val otherWritableRawIds = mutableListOf<Long>()

        val projection = mutableListOf(
            RawContacts._ID,
            RawContacts.ACCOUNT_TYPE,
        ).apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                add(RawContacts.RAW_CONTACT_IS_READ_ONLY)
            }
        }.toTypedArray()

        try {
            resolver.query(
                RawContacts.CONTENT_URI,
                projection,
                "${RawContacts.CONTACT_ID} = ? AND ${RawContacts.DELETED} = 0",
                arrayOf(contactId),
                null,
            )?.use { cursor ->
                val idIdx = cursor.getColumnIndex(RawContacts._ID)
                val typeIdx = cursor.getColumnIndex(RawContacts.ACCOUNT_TYPE)
                val readOnlyIdx = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    cursor.getColumnIndex(RawContacts.RAW_CONTACT_IS_READ_ONLY)
                } else {
                    -1
                }
                while (cursor.moveToNext()) {
                    if (idIdx < 0) continue
                    val rawId = cursor.getLong(idIdx)
                    val accountType = if (typeIdx >= 0) cursor.getString(typeIdx) else null
                    val isReadOnly = readOnlyIdx >= 0 && cursor.getInt(readOnlyIdx) == 1
                    if (isReadOnly) continue
                    if (accountType != null && accountType in THIRD_PARTY_SYNC_ACCOUNTS) continue

                    if (accountType == "com.google") {
                        googleRawIds.add(rawId)
                    } else {
                        otherWritableRawIds.add(rawId)
                    }
                }
            }
        } catch (_: Throwable) {
            return false
        }

        val targetRawIds = if (googleRawIds.isNotEmpty()) googleRawIds else otherWritableRawIds
        if (targetRawIds.isEmpty()) return false

        var wroteAny = false
        for (rawId in targetRawIds) {
            try {
                // 1. Write full-size JPEG to RawContacts.DisplayPhoto
                val displayPhotoUri = Uri.withAppendedPath(
                    ContentUris.withAppendedId(RawContacts.CONTENT_URI, rawId),
                    RawContacts.DisplayPhoto.CONTENT_DIRECTORY,
                )
                resolver.openAssetFileDescriptor(displayPhotoUri, "rw")?.use { afd ->
                    afd.createOutputStream().use { out ->
                        out.write(photoBytes)
                        out.flush()
                    }
                }
                wroteAny = true
            } catch (_: Throwable) {
                // Fall back cleanly to Data PHOTO row below
            }

            try {
                // 2. Also ensure Data.Photo row carries thumbnail + IS_SUPER_PRIMARY
                val values = ContentValues().apply {
                    put(Photo.PHOTO, thumbBytes)
                    put(Data.IS_PRIMARY, 1)
                    put(Data.IS_SUPER_PRIMARY, 1)
                }
                var existingDataId: Long? = null
                resolver.query(
                    Data.CONTENT_URI,
                    arrayOf(Data._ID),
                    "${Data.RAW_CONTACT_ID} = ? AND ${Data.MIMETYPE} = ?",
                    arrayOf(rawId.toString(), Photo.CONTENT_ITEM_TYPE),
                    null,
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        existingDataId = cursor.getLong(0)
                    }
                }

                if (existingDataId != null) {
                    resolver.update(
                        ContentUris.withAppendedId(Data.CONTENT_URI, existingDataId!!),
                        values,
                        null,
                        null,
                    )
                } else {
                    values.put(Data.RAW_CONTACT_ID, rawId)
                    values.put(Data.MIMETYPE, Photo.CONTENT_ITEM_TYPE)
                    resolver.insert(Data.CONTENT_URI, values)
                }

                // 3. Mark raw contact dirty so Google Contacts Sync Adapter uploads the photo
                val dirtyValues = ContentValues().apply {
                    put(RawContacts.DIRTY, 1)
                }
                resolver.update(
                    ContentUris.withAppendedId(RawContacts.CONTENT_URI, rawId),
                    dirtyValues,
                    null,
                    null,
                )
                wroteAny = true
            } catch (_: Throwable) {
                // Ignore per-raw-contact failure and continue
            }
        }
        return wroteAny
    }
}
