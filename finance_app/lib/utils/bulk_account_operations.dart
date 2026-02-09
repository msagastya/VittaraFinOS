import 'dart:convert';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';

/// Utility class for performing bulk operations on accounts
/// Supports delete, archive, export, and bulk property updates
class BulkAccountOperations {
  BulkAccountOperations._();

  /// Delete multiple accounts at once
  /// Returns the number of successfully deleted accounts
  static Future<int> deleteAccounts(
    AccountsController controller,
    List<String> accountIds,
  ) async {
    int deletedCount = 0;

    for (final accountId in accountIds) {
      try {
        await controller.removeAccount(accountId);
        deletedCount++;
      } catch (e) {
        // Continue with other deletions even if one fails
        continue;
      }
    }

    return deletedCount;
  }

  /// Archive multiple accounts at once
  /// Updates the metadata to mark accounts as archived
  /// Returns the number of successfully archived accounts
  static Future<int> archiveAccounts(
    AccountsController controller,
    List<String> accountIds,
  ) async {
    int archivedCount = 0;

    for (final accountId in accountIds) {
      try {
        final account = controller.accounts.firstWhere(
          (acc) => acc.id == accountId,
        );

        final updatedAccount = account.copyWith(
          metadata: {
            ...?account.metadata,
            'archived': true,
            'archivedAt': DateTime.now().toIso8601String(),
          },
        );

        await controller.updateAccount(updatedAccount);
        archivedCount++;
      } catch (e) {
        // Continue with other archives even if one fails
        continue;
      }
    }

    return archivedCount;
  }

  /// Unarchive multiple accounts at once
  /// Removes the archived flag from metadata
  /// Returns the number of successfully unarchived accounts
  static Future<int> unarchiveAccounts(
    AccountsController controller,
    List<String> accountIds,
  ) async {
    int unarchivedCount = 0;

    for (final accountId in accountIds) {
      try {
        final account = controller.accounts.firstWhere(
          (acc) => acc.id == accountId,
        );

        final metadata = Map<String, dynamic>.from(account.metadata ?? {});
        metadata.remove('archived');
        metadata.remove('archivedAt');

        final updatedAccount = account.copyWith(
          metadata: metadata.isNotEmpty ? metadata : null,
        );

        await controller.updateAccount(updatedAccount);
        unarchivedCount++;
      } catch (e) {
        // Continue with other unarchives even if one fails
        continue;
      }
    }

    return unarchivedCount;
  }

  /// Export account data to JSON format
  /// Returns a JSON string containing all account data
  static String exportAccountsToJson(
    AccountsController controller,
    List<String> accountIds,
  ) {
    final accountsToExport = controller.accounts
        .where((acc) => accountIds.contains(acc.id))
        .toList();

    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': '1.0',
      'accountCount': accountsToExport.length,
      'accounts': accountsToExport.map((acc) => acc.toMap()).toList(),
    };

    return jsonEncode(exportData);
  }

  /// Export all accounts to JSON format
  static String exportAllAccountsToJson(AccountsController controller) {
    final allAccountIds = controller.accounts.map((acc) => acc.id).toList();
    return exportAccountsToJson(controller, allAccountIds);
  }

  /// Bulk update account property
  /// Updates a specific property for multiple accounts
  /// Returns the number of successfully updated accounts
  static Future<int> bulkUpdateProperty(
    AccountsController controller,
    List<String> accountIds,
    String propertyKey,
    dynamic propertyValue,
  ) async {
    int updatedCount = 0;

    for (final accountId in accountIds) {
      try {
        final account = controller.accounts.firstWhere(
          (acc) => acc.id == accountId,
        );

        final updatedAccount = account.copyWith(
          metadata: {
            ...?account.metadata,
            propertyKey: propertyValue,
          },
        );

        await controller.updateAccount(updatedAccount);
        updatedCount++;
      } catch (e) {
        // Continue with other updates even if one fails
        continue;
      }
    }

    return updatedCount;
  }

  /// Bulk set account type
  /// Changes the type for multiple accounts
  /// Returns the number of successfully updated accounts
  static Future<int> bulkSetAccountType(
    AccountsController controller,
    List<String> accountIds,
    AccountType newType,
  ) async {
    int updatedCount = 0;

    for (final accountId in accountIds) {
      try {
        final account = controller.accounts.firstWhere(
          (acc) => acc.id == accountId,
        );

        final updatedAccount = account.copyWith(type: newType);

        await controller.updateAccount(updatedAccount);
        updatedCount++;
      } catch (e) {
        // Continue with other updates even if one fails
        continue;
      }
    }

    return updatedCount;
  }

  /// Get archived accounts
  /// Returns list of accounts that are marked as archived
  static List<Account> getArchivedAccounts(AccountsController controller) {
    return controller.accounts.where((acc) {
      final metadata = acc.metadata;
      if (metadata == null) return false;
      return metadata['archived'] == true;
    }).toList();
  }

  /// Get active (non-archived) accounts
  /// Returns list of accounts that are not archived
  static List<Account> getActiveAccounts(AccountsController controller) {
    return controller.accounts.where((acc) {
      final metadata = acc.metadata;
      if (metadata == null) return true;
      return metadata['archived'] != true;
    }).toList();
  }

  /// Calculate total balance across multiple accounts
  /// Returns the sum of balances for specified accounts
  static double calculateTotalBalance(
    AccountsController controller,
    List<String> accountIds,
  ) {
    return controller.accounts
        .where((acc) => accountIds.contains(acc.id))
        .fold(0.0, (sum, acc) => sum + acc.balance);
  }

  /// Group accounts by type
  /// Returns a map of account type to list of accounts
  static Map<AccountType, List<Account>> groupAccountsByType(
    AccountsController controller,
  ) {
    final grouped = <AccountType, List<Account>>{};

    for (final account in controller.accounts) {
      if (!grouped.containsKey(account.type)) {
        grouped[account.type] = [];
      }
      grouped[account.type]!.add(account);
    }

    return grouped;
  }

  /// Bulk tag accounts with a custom tag
  /// Adds a tag to multiple accounts' metadata
  /// Returns the number of successfully tagged accounts
  static Future<int> bulkTagAccounts(
    AccountsController controller,
    List<String> accountIds,
    String tag,
  ) async {
    int taggedCount = 0;

    for (final accountId in accountIds) {
      try {
        final account = controller.accounts.firstWhere(
          (acc) => acc.id == accountId,
        );

        final existingTags = (account.metadata?['tags'] as List?)?.cast<String>() ?? [];
        if (!existingTags.contains(tag)) {
          existingTags.add(tag);
        }

        final updatedAccount = account.copyWith(
          metadata: {
            ...?account.metadata,
            'tags': existingTags,
          },
        );

        await controller.updateAccount(updatedAccount);
        taggedCount++;
      } catch (e) {
        // Continue with other tags even if one fails
        continue;
      }
    }

    return taggedCount;
  }

  /// Bulk remove tag from accounts
  /// Removes a specific tag from multiple accounts' metadata
  /// Returns the number of successfully updated accounts
  static Future<int> bulkRemoveTag(
    AccountsController controller,
    List<String> accountIds,
    String tag,
  ) async {
    int updatedCount = 0;

    for (final accountId in accountIds) {
      try {
        final account = controller.accounts.firstWhere(
          (acc) => acc.id == accountId,
        );

        final existingTags = (account.metadata?['tags'] as List?)?.cast<String>() ?? [];
        existingTags.remove(tag);

        final updatedAccount = account.copyWith(
          metadata: {
            ...?account.metadata,
            'tags': existingTags,
          },
        );

        await controller.updateAccount(updatedAccount);
        updatedCount++;
      } catch (e) {
        // Continue with other updates even if one fails
        continue;
      }
    }

    return updatedCount;
  }

  /// Export accounts to CSV format
  /// Returns a CSV string with account data
  static String exportAccountsToCSV(
    AccountsController controller,
    List<String> accountIds,
  ) {
    final accountsToExport = controller.accounts
        .where((acc) => accountIds.contains(acc.id))
        .toList();

    final csvRows = <String>[];

    // Header
    csvRows.add('ID,Name,Type,Balance,Currency,Credit Limit,Institution Name,Created Date');

    // Data rows
    for (final account in accountsToExport) {
      final row = [
        account.id,
        _escapeCsvValue(account.name),
        account.type.name,
        account.balance.toString(),
        account.currency,
        account.creditLimit?.toString() ?? '',
        _escapeCsvValue(account.institutionName ?? ''),
        account.createdDate.toIso8601String(),
      ];
      csvRows.add(row.join(','));
    }

    return csvRows.join('\n');
  }

  /// Helper method to escape CSV values
  static String _escapeCsvValue(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Get accounts by institution
  /// Returns accounts grouped by institution name
  static Map<String, List<Account>> groupAccountsByInstitution(
    AccountsController controller,
  ) {
    final grouped = <String, List<Account>>{};

    for (final account in controller.accounts) {
      final institution = account.institutionName ?? 'Unknown';
      if (!grouped.containsKey(institution)) {
        grouped[institution] = [];
      }
      grouped[institution]!.add(account);
    }

    return grouped;
  }
}
