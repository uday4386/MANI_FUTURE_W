import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class ShortsCommentsModal extends StatefulWidget {
  final Map<String, dynamic> short;
  final bool isEnglish;

  const ShortsCommentsModal({
    super.key,
    required this.short,
    required this.isEnglish,
  });

  @override
  State<ShortsCommentsModal> createState() => _ShortsCommentsModalState();
}

class _ShortsCommentsModalState extends State<ShortsCommentsModal> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final res = await ApiService.getShortComments(widget.short['id'].toString());
      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching short comments: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // Use SharedPreferences fallback for user instead of Supabase Auth
    final prefs = await SharedPreferences.getInstance();
    
    String userId = prefs.getString('user_id') ?? '';
    
    // If no user_id exists, create a persistent guest_id
    if (userId.isEmpty) {
      userId = prefs.getString('guest_id') ?? '';
      if (userId.isEmpty) {
        userId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('guest_id', userId);
      }
    }

    final savedName = prefs.getString('user_name') ?? (userId.startsWith('guest_') ? 'Guest User' : 'User');

    // Optimistic UI update
    final newComment = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'comment_text': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'user_id': userId,
      'user_name': savedName,
    };

    setState(() {
      _comments.insert(0, newComment);
      _commentController.clear();
    });

    try {
      final res = await ApiService.postComment(
        widget.short['id'].toString(), 
        userId, 
        savedName, 
        text
      );

      // Update the temp comment with real ID
      setState(() {
        final idx = _comments.indexWhere((c) => c['id'] == newComment['id']);
        if (idx != -1) {
          _comments[idx]['id'] = res['id'];
        }
      });
    } catch (e) {
      debugPrint("Error posting comment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEnglish
                ? "Failed to post comment"
                : "కామెంట్ పోస్ట్ చేయడం విఫలమైంది",
          ),
        ),
      );
      // Remove failed optimistic comment
      setState(() {
        _comments.removeWhere((c) => c['id'] == newComment['id']);
      });
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await ApiService.deleteShortComment(commentId);
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c['id'].toString() == commentId);
        });
      }
    } catch (e) {
      debugPrint("Error deleting comment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEnglish
                  ? "Failed to delete comment"
                  : "వ్యాఖ్య తొలగించడం విఫలమైంది",
            ),
          ),
        );
      }
    }
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 7) {
        return DateFormat('MMM d, y').format(dt);
      } else if (diff.inDays > 0) {
        return "${diff.inDays} d";
      } else if (diff.inHours > 0) {
        return "${diff.inHours} h";
      } else if (diff.inMinutes > 0) {
        return "${diff.inMinutes} m";
      } else {
        return "now";
      }
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F2027) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    final double screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      height: screenHeight * 0.65,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.isEnglish ? "Comments" : "వ్యాఖ్యలు",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Comments List
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: const Color(0xFFFFC107)),
                  )
                : _comments.isEmpty
                ? Center(
                    child: Text(
                      widget.isEnglish
                          ? "No comments yet. Be the first!"
                          : "ఇంకా వ్యాఖ్యలు లేవు. మొదట మీరే వ్యాఖ్యానించండి!",
                      style: TextStyle(color: subTextColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: _comments.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final c = _comments[index];
                      final authorName = c['user_name'] ?? 'User';
                      return FutureBuilder<SharedPreferences>(
                        future: SharedPreferences.getInstance(),
                        builder: (context, snapshot) {
                          final prefs = snapshot.data;
                          final userId = prefs?.getString('user_id') ?? '';
                          final guestId = prefs?.getString('guest_id') ?? '';
                          final effectiveId = userId.isNotEmpty ? userId : guestId;
                          final bool isMyComment = c['user_id'] != null && c['user_id'].toString() == effectiveId;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.grey.shade800,
                                  child: Text(
                                    authorName
                                        .toString()
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            authorName,
                                            style: TextStyle(
                                              color: subTextColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatTime(c['created_at']),
                                            style: TextStyle(
                                              color: subTextColor,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        c['comment_text'] ?? '',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isMyComment)
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: Colors.red.shade400,
                                    ),
                                    onPressed: () => _deleteComment(c['id'].toString()),
                                  ),
                              ],
                            ),
                          );
                        }
                      );
                    },
                  ),
          ),

          // Input Box
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom:
                  MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom +
                  12,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF132A35) : Colors.grey.shade100,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: widget.isEnglish
                          ? "Add a comment..."
                          : "వ్యాఖ్యానించండి...",
                      hintStyle: TextStyle(color: subTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1F3A47)
                          : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _postComment,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
