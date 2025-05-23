import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'fridge_detail_page.dart'; // SortOption enum 가져오기

class FridgeItemList extends StatefulWidget {
  final String fridgeId;
  final String place;
  final SortOption sortOption;

  const FridgeItemList({
    Key? key,
    required this.fridgeId,
    required this.place,
    required this.sortOption,
  }) : super(key: key);

  @override
  _FridgeItemListState createState() => _FridgeItemListState();
}

class _FridgeItemListState extends State<FridgeItemList> {
  final userId = FirebaseAuth.instance.currentUser?.uid ?? 'sampleUser';

  Stream<QuerySnapshot> getItemsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('fridges')
        .doc(widget.fridgeId)
        .collection('fridge_items')
        .where('place', isEqualTo: widget.place)
        .snapshots();
  }

  Future<void> _showItemDialog(BuildContext context,
      {DocumentSnapshot? item}) async {
    final isEdit = item != null;
    String name = item?['name'] ?? '';
    int count = item?['count'] ?? 1;
    DateTime day = isEdit && item?['day'] != null
        ? DateTime.parse(item!['day'])
        : DateTime.now();

    final nameController = TextEditingController(text: name);

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('${widget.place}에 식재료 ${isEdit ? '수정' : '추가'}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("식재료 이름",
                      style: TextStyle(fontSize: 12, color: Colors.purple)),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(isDense: true),
                    onChanged: (v) => name = v,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Text('유통기한: ${DateFormat('yyyy-MM-dd').format(day)}'),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: day,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => day = picked);
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Text('개수: '),
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () =>
                            setState(() => count = count > 1 ? count - 1 : 1),
                      ),
                      Text('$count'),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () => setState(() => count++),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('취소', style: TextStyle(color: Colors.purple)),
                ),
                if (isEdit)
                  TextButton(
                    onPressed: () async {
                      await item!.reference.delete();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Text('삭제', style: TextStyle(color: Colors.redAccent)),
                  ),
                TextButton(
                  onPressed: () async {
                    name = nameController.text;
                    if (name.isNotEmpty) {
                      final data = {
                        'name': name,
                        'count': count,
                        'day': DateFormat('yyyy-MM-dd').format(day),
                        'place': widget.place,
                      };
                      if (isEdit) {
                        await item!.reference.update(data);
                      } else {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .collection('fridges')
                            .doc(widget.fridgeId)
                            .collection('fridge_items')
                            .add(data);
                      }
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                  child: Text(isEdit ? '수정' : '추가'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<DocumentSnapshot> _sortedDocs(List<DocumentSnapshot> docs) {
    final list = List<DocumentSnapshot>.from(docs);
    switch (widget.sortOption) {
      case SortOption.expiryAsc:
        list.sort((a, b) =>
            DateTime.parse(a['day']).compareTo(DateTime.parse(b['day'])));
        break;
      case SortOption.expiryDesc:
        list.sort((a, b) =>
            DateTime.parse(b['day']).compareTo(DateTime.parse(a['day'])));
        break;
      case SortOption.countDesc:
        list.sort((a, b) =>
            (b['count'] as int).compareTo(a['count'] as int));
        break;
      case SortOption.countAsc:
        list.sort((a, b) =>
            (a['count'] as int).compareTo(b['count'] as int));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: getItemsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('오류: ${snap.error}'));
        }

        final docs = snap.data?.docs ?? [];
        final items = _sortedDocs(docs);

        return Stack(
          children: [
            docs.isEmpty
                ? Center(child: Text('식재료가 없습니다'))
                : ListView.separated(
              padding: EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                final expiryDate = DateTime.parse(item['day']);
                final today = DateTime.now();
                final todayDateOnly =
                DateTime(today.year, today.month, today.day);
                final isExpired = expiryDate.isBefore(todayDateOnly);
                final isExpiring = expiryDate.isBefore(
                    todayDateOnly.add(Duration(days: 3))) &&
                    !isExpired;

                return Container(
                  padding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.grey.shade400
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4)
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name'],
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            Text('수량: ${item['count']}'),
                            Text('유통기한: ${item['day']}',
                                style: TextStyle(
                                    color: isExpiring
                                        ? Colors.red
                                        : Colors.black)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () =>
                            _showItemDialog(context, item: item),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () => _showItemDialog(context),
                child: Icon(Icons.add),
                backgroundColor: Colors.blue,
              ),
            ),
          ],
        );
      },
    );
  }
}
