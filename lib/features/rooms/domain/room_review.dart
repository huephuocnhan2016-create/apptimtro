/// Một lượt đánh giá phòng của sinh viên đã cọc.
class RoomReview {
  const RoomReview({
    required this.id,
    required this.rating,
    required this.author,
    required this.createdAt,
    this.comment,
  });

  final String id;
  final int rating;
  final String author;
  final String? comment;
  final DateTime createdAt;

  factory RoomReview.fromJson(Map<String, dynamic> json) => RoomReview(
    id: json['id'] as String? ?? '',
    rating: (json['rating'] as num?)?.toInt() ?? 0,
    author: json['author'] as String? ?? 'Sinh viên',
    comment: json['comment'] as String?,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}
