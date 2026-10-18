import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SaloFirebaseRepository {
  SaloFirebaseRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore,
       _functions = functions;

  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  FirebaseFunctions get functions =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<List<Map<String, dynamic>>> loadConversations(String uid) async {
    final snapshot = await firestore
        .collection('chats')
        .where('memberUids', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .get();
    return snapshot.docs.map((document) {
      final data = document.data();
      final participants = Map<String, dynamic>.from(
        (data['participants'] as Map?) ?? const <String, dynamic>{},
      );
      final otherUids = (data['memberUids'] as List? ?? const [])
          .whereType<String>()
          .where((memberUid) => memberUid != uid)
          .toList();
      final otherUid = otherUids.isEmpty ? null : otherUids.first;
      final other = otherUid == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(
              (participants[otherUid] as Map?) ?? const <String, dynamic>{},
            );
      return <String, dynamic>{
        'id': document.id,
        'chatId': document.id,
        'otherUid': otherUid ?? '',
        'username': (other['username'] ?? '').toString(),
        'name': (other['displayName'] ?? 'محادثة').toString(),
        'lastMessage': (data['lastMessage'] ?? 'لا توجد رسائل').toString(),
      };
    }).toList();
  }

  Future<String> startDirectChat(String username) async {
    final result = await functions.httpsCallable('startDirectChat').call(
      <String, Object?>{'username': username.trim()},
    );
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['chatId'].toString();
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String chatId, String uid) {
    return firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .limitToLast(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((document) {
            final data = document.data();
            return <String, dynamic>{
              'id': document.id,
              'senderUid': data['senderUid'],
              'sent': data['senderUid'] == uid,
              'text': data['text'],
              'type': data['type'] ?? 'text',
            };
          }).toList(),
        );
  }

  Future<void> sendMessage(
    String chatId,
    String text, {
    required String clientMessageId,
  }) async {
    await functions.httpsCallable('sendMessage').call(<String, Object?>{
      'chatId': chatId,
      'text': text,
      'clientMessageId': clientMessageId,
    });
  }

  Future<List<Map<String, dynamic>>> loadStories() async {
    final result = await functions.httpsCallable('listStories').call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['stories'] as List? ?? const [])
        .whereType<Map>()
        .map((story) => Map<String, dynamic>.from(story))
        .toList();
  }

  Future<void> createStory(String text) async {
    await functions.httpsCallable('createStory').call(<String, Object?>{
      'type': 'text',
      'text': text,
      'visibility': 'friends',
    });
  }

  Future<void> deleteStory(String storyId) async {
    await functions.httpsCallable('deleteStory').call(<String, Object?>{
      'storyId': storyId,
    });
  }

  Future<List<Map<String, dynamic>>> loadGroups() async {
    final snapshot = await firestore
        .collection('groups')
        .where('isPublic', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .get();
    return snapshot.docs.map((document) {
      final data = document.data();
      return <String, dynamic>{'id': document.id, ...data};
    }).toList();
  }

  Future<void> createGroup(String name, String description) async {
    await functions.httpsCallable('createGroup').call(<String, Object?>{
      'name': name,
      'description': description,
    });
  }

  Future<void> joinGroup(String groupId) async {
    await functions.httpsCallable('joinGroup').call(<String, Object?>{
      'groupId': groupId,
    });
  }

  Future<Map<String, dynamic>> loadSettings(String uid) async {
    final snapshot = await firestore.collection('userSettings').doc(uid).get();
    return snapshot.data() ?? <String, dynamic>{};
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await functions.httpsCallable('saveUserSettings').call(<String, Object?>{
      'settings': settings,
    });
  }
}
