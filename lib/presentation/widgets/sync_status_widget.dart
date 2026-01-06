import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../bloc/sync_bloc.dart';

/// Widget that displays the current sync status with visual indicators
/// 
/// Shows:
/// - Syncing spinner when sync is in progress
/// - Checkmark when all transactions are synced
/// - Warning icon when there's an error
/// - Pending count badge when transactions are waiting to sync
/// - Offline indicator when device is offline
/// 
/// Requirements: 3.1, 3.2, 3.3, 3.4
class SyncStatusWidget extends StatelessWidget {
  /// Whether to show the pending count badge
  final bool showPendingBadge;
  
  /// Whether to show the status text
  final bool showStatusText;
  
  /// Size of the icon
  final double iconSize;
  
  /// Callback when the widget is tapped
  final VoidCallback? onTap;

  const SyncStatusWidget({
    super.key,
    this.showPendingBadge = true,
    this.showStatusText = false,
    this.iconSize = 24.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncBlocState>(
      builder: (context, state) {
        return GestureDetector(
          onTap: onTap,
          child: _buildStatusIndicator(context, state),
        );
      },
    );
  }

  Widget _buildStatusIndicator(BuildContext context, SyncBlocState state) {
    final theme = Theme.of(context);
    
    // Determine icon, color, and tooltip based on state
    final statusInfo = _getStatusInfo(state, theme);
    
    return Tooltip(
      message: statusInfo.tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon with optional badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Main icon or spinner
              if (state is SyncInProgress)
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(statusInfo.color),
                  ),
                )
              else
                Icon(
                  statusInfo.icon,
                  color: statusInfo.color,
                  size: iconSize,
                ),
              
              // Pending count badge
              if (showPendingBadge && state.pendingCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: _buildPendingBadge(context, state.pendingCount),
                ),
            ],
          ),
          
          // Optional status text
          if (showStatusText) ...[
            const SizedBox(width: 8),
            Text(
              statusInfo.text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: statusInfo.color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingBadge(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.warningOrange,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(
        minWidth: 18,
        minHeight: 18,
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  _StatusInfo _getStatusInfo(SyncBlocState state, ThemeData theme) {
    if (state is SyncInProgress) {
      return _StatusInfo(
        icon: Icons.sync,
        color: theme.colorScheme.primary,
        text: 'Syncing...',
        tooltip: 'Syncing ${state.pendingCount} transaction${state.pendingCount == 1 ? '' : 's'}',
      );
    }
    
    if (state is SyncComplete) {
      return const _StatusInfo(
        icon: Icons.cloud_done,
        color: AppTheme.successGreen,
        text: 'All synced',
        tooltip: 'All transactions synced',
      );
    }
    
    if (state is SyncPending) {
      return _StatusInfo(
        icon: Icons.cloud_upload_outlined,
        color: AppTheme.warningOrange,
        text: '${state.pendingCount} pending',
        tooltip: '${state.pendingCount} transaction${state.pendingCount == 1 ? '' : 's'} pending sync',
      );
    }
    
    if (state is SyncError) {
      return _StatusInfo(
        icon: Icons.cloud_off,
        color: AppTheme.errorRed,
        text: 'Sync error',
        tooltip: state.message,
      );
    }
    
    if (state is SyncOffline) {
      return _StatusInfo(
        icon: Icons.cloud_off_outlined,
        color: Colors.grey,
        text: 'Offline',
        tooltip: 'Device is offline. ${state.pendingCount} transaction${state.pendingCount == 1 ? '' : 's'} will sync when online.',
      );
    }
    
    // SyncInitial or unknown state
    return _StatusInfo(
      icon: Icons.cloud_outlined,
      color: theme.colorScheme.onSurfaceVariant,
      text: 'Ready',
      tooltip: 'Sync ready',
    );
  }
}

/// Internal class to hold status information
class _StatusInfo {
  final IconData icon;
  final Color color;
  final String text;
  final String tooltip;

  const _StatusInfo({
    required this.icon,
    required this.color,
    required this.text,
    required this.tooltip,
  });
}

/// Expanded sync status card widget for displaying detailed sync information
/// 
/// Shows sync status with more details including:
/// - Current sync state with icon
/// - Pending transaction count
/// - Last sync time
/// - Manual sync button
/// 
/// Requirements: 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3
class SyncStatusCard extends StatelessWidget {
  /// Callback when manual sync is triggered
  final VoidCallback? onManualSync;

  const SyncStatusCard({
    super.key,
    this.onManualSync,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncBlocState>(
      builder: (context, state) {
        return Card(
          margin: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Icon(
                      Icons.cloud_sync,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cloud Sync',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    const SyncStatusWidget(
                      showPendingBadge: true,
                      showStatusText: false,
                      iconSize: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Status message
                _buildStatusMessage(context, state),
                const SizedBox(height: 12),
                
                // Action buttons
                _buildActionButtons(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusMessage(BuildContext context, SyncBlocState state) {
    final theme = Theme.of(context);
    String message;
    Color? textColor;
    IconData messageIcon;

    if (state is SyncInProgress) {
      message = 'Syncing transactions to cloud...';
      textColor = theme.colorScheme.primary;
      messageIcon = Icons.sync;
    } else if (state is SyncComplete) {
      message = 'All transactions synced to cloud';
      textColor = AppTheme.successGreen;
      messageIcon = Icons.check_circle_outline;
    } else if (state is SyncPending) {
      message = '${state.pendingCount} transaction${state.pendingCount == 1 ? '' : 's'} waiting to sync';
      textColor = AppTheme.warningOrange;
      messageIcon = Icons.cloud_upload_outlined;
    } else if (state is SyncError) {
      message = state.message;
      textColor = AppTheme.errorRed;
      messageIcon = Icons.error_outline;
    } else if (state is SyncOffline) {
      message = 'Device is offline. ${state.pendingCount} transaction${state.pendingCount == 1 ? '' : 's'} will sync when online.';
      textColor = Colors.grey.shade700;
      messageIcon = Icons.cloud_off_outlined;
    } else {
      message = 'Sync service ready';
      textColor = theme.colorScheme.onSurfaceVariant;
      messageIcon = Icons.info_outline;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          messageIcon,
          size: 16,
          color: textColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, SyncBlocState state) {
    final isSyncing = state is SyncInProgress;
    final isOffline = state is SyncOffline;
    final hasPending = state.pendingCount > 0;

    return Row(
      children: [
        // Manual sync button
        if (!isOffline && hasPending)
          ElevatedButton.icon(
            onPressed: isSyncing ? null : () {
              context.read<SyncBloc>().add(SyncRequested());
              onManualSync?.call();
            },
            icon: isSyncing 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 18),
            label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isSyncing 
                  ? Colors.grey.shade200 
                  : AppTheme.primaryBlue.withValues(alpha: 0.1),
              foregroundColor: isSyncing 
                  ? Colors.grey 
                  : AppTheme.primaryBlue,
            ),
          ),
        
        // Show "All synced" indicator when complete
        if (state is SyncComplete)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: AppTheme.successGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  'All synced',
                  style: TextStyle(
                    color: AppTheme.successGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        
        // Offline indicator
        if (isOffline)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off,
                  size: 16,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  'Offline',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Small sync indicator for use in transaction list items
/// 
/// Shows a simple cloud icon indicating sync status:
/// - Cloud with checkmark: synced
/// - Cloud with upload arrow: pending sync
/// 
/// Requirements: 2.5, 3.1
class TransactionSyncIndicator extends StatelessWidget {
  /// Whether the transaction has been synced to cloud
  final bool isSynced;
  
  /// Size of the icon
  final double size;

  const TransactionSyncIndicator({
    super.key,
    required this.isSynced,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isSynced ? 'Synced to cloud' : 'Pending sync',
      child: Icon(
        isSynced ? Icons.cloud_done : Icons.cloud_upload_outlined,
        size: size,
        color: isSynced ? AppTheme.successGreen : AppTheme.warningOrange,
      ),
    );
  }
}
