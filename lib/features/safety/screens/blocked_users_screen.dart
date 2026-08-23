import 'package:flutter/material.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/profile.dart';
import '../safety_repository.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _repository = SafetyRepository();
  late Future<List<Profile>> _future;
  String? _unblockingId;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchBlockedUsers();
  }

  Future<void> _unblock(Profile profile) async {
    setState(() => _unblockingId = profile.id);
    try {
      await _repository.unblockUser(profile.id);
      if (!mounted) return;
      setState(() => _future = _repository.fetchBlockedUsers());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not unblock: $e')),
      );
    } finally {
      if (mounted) setState(() => _unblockingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 10, bottom: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TopBar(eyebrow: 'SAFETY', title: 'Blocked users'),
              FutureBuilder<List<Profile>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorView(message: 'Could not load: ${snapshot.error}');
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingView();
                  }
                  final blocked = snapshot.data!;
                  if (blocked.isEmpty) {
                    return const EmptyView(
                      icon: Icons.block_outlined,
                      title: 'Nobody blocked',
                      message: 'People you block can no longer message you.',
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kGutter),
                    child: Column(
                      children: [
                        for (final profile in blocked)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              margin: EdgeInsets.zero,
                              radius: 19,
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(profile.fullName, style: AppText.cardTitle),
                                  ),
                                  TextButton(
                                    onPressed: _unblockingId == profile.id
                                        ? null
                                        : () => _unblock(profile),
                                    child: _unblockingId == profile.id
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Unblock'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
