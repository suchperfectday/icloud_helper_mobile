class ICloudFile {
  final String relativePath;
  final int sizeInBytes;
  final DateTime creationDate;
  final DateTime contentChangeDate;
  final bool isDownloading;
  final DownloadStatus downloadStatus;
  final bool isUploading;
  final bool isUploaded;
  final bool hasUnresolvedConflicts;

  ICloudFile.fromMap(Map<dynamic, dynamic> map)
      : relativePath = map['relativePath'] as String,
        sizeInBytes = map['sizeInBytes'],
        creationDate = DateTime.fromMillisecondsSinceEpoch(((map['creationDate'] as double) * 1000).round()),
        contentChangeDate = DateTime.fromMillisecondsSinceEpoch(((map['contentChangeDate'] as double) * 1000).round()),
        isDownloading = map['isDownloading'],
        downloadStatus = _mapToDownloadStatusFromNSKeys(map['downloadStatus']),
        isUploading = map['isUploading'],
        isUploaded = map['isUploaded'],
        hasUnresolvedConflicts = map['hasUnresolvedConflicts'];

  static DownloadStatus _mapToDownloadStatusFromNSKeys(String key) {
    switch (key) {
      case 'NSMetadataUbiquitousItemDownloadingStatusNotDownloaded':
        return DownloadStatus.notDownloaded;
      case 'NSMetadataUbiquitousItemDownloadingStatusDownloaded':
        return DownloadStatus.downloaded;
      case 'NSMetadataUbiquitousItemDownloadingStatusCurrent':
        return DownloadStatus.current;
      default:
        throw 'NSMetadataUbiquitousItemDownloadingStatusKey is not handled';
    }
  }
}

enum DownloadStatus {
  notDownloaded,
  downloaded,
  current,
}
