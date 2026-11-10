import 'package:apptimtro/features/rooms/domain/room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses room fields, images, distance, and landlord contact', () {
    final room = Room.fromJson({
      'id': 'room-1',
      'title': 'Phòng gần trường',
      'description': 'Có ban công',
      'address': 'Quận 1',
      'latitude': 10.77,
      'longitude': 106.66,
      'price': 4500000,
      'area': 22.5,
      'totalRooms': 4,
      'availableRooms': 2,
      'electricityPrice': 3000,
      'waterPrice': 12000,
      'internetPrice': 100000,
      'deposit': 4500000,
      'status': 'AVAILABLE',
      'distance': 1.4,
      'amenities': ['wifi', 'parking'],
      'images': [
        {'imageUrl': 'https://example.invalid/room.jpg', 'sortOrder': 0},
      ],
      'landlord': {'fullName': 'Chủ trọ', 'phone': '0900000000'},
    });

    expect(room.title, 'Phòng gần trường');
    expect(room.price, 4500000);
    expect(room.availableRooms, 2);
    expect(room.distance, 1.4);
    expect(room.image, 'https://example.invalid/room.jpg');
    expect(room.amenities, ['wifi', 'parking']);
    expect(room.landlordPhone, '0900000000');
  });

  test('reads the rating block and defaults it when absent', () {
    final reviewed = Room.fromJson({
      'id': 'room-1',
      'title': 'Phòng đã có người đánh giá',
      'address': 'Quận 1',
      'price': 4500000,
      'area': 22.5,
      'totalRooms': 4,
      'availableRooms': 2,
      'electricityPrice': 3000,
      'waterPrice': 12000,
      'internetPrice': 100000,
      'deposit': 4500000,
      'rating': {'average': 4.5, 'count': 2},
      'canReview': true,
    });
    final fresh = Room.fromJson({
      'id': 'room-2',
      'title': 'Phòng chưa có đánh giá',
      'address': 'Quận 1',
      'price': 4500000,
      'area': 22.5,
      'totalRooms': 4,
      'availableRooms': 2,
      'electricityPrice': 3000,
      'waterPrice': 12000,
      'internetPrice': 100000,
      'deposit': 4500000,
    });

    expect(reviewed.ratingAverage, 4.5);
    expect(reviewed.ratingCount, 2);
    expect(reviewed.canReview, isTrue);
    expect(fresh.ratingAverage, isNull);
    expect(fresh.ratingCount, 0);
    expect(fresh.canReview, isFalse);
  });

  test('parses address-only rooms without coordinates', () {
    final room = Room.fromJson({
      'id': 'room-without-location',
      'title': 'Phòng chưa ghim bản đồ',
      'description': '',
      'address': 'Quận 1, Thành phố Hồ Chí Minh',
      'latitude': null,
      'longitude': null,
      'price': 4500000,
      'area': 22.5,
      'totalRooms': 4,
      'availableRooms': 2,
      'electricityPrice': 3000,
      'waterPrice': 12000,
      'internetPrice': 100000,
      'deposit': 4500000,
      'status': 'AVAILABLE',
    });

    expect(room.address, 'Quận 1, Thành phố Hồ Chí Minh');
    expect(room.latitude, isNull);
    expect(room.longitude, isNull);
  });

  test('reads the deposit the student already holds on a room', () {
    Room withDeposit(bool held) => Room.fromJson({
      'id': 'room-1',
      'title': 'Phòng gần trường',
      'address': 'Quận 1',
      'price': 4500000,
      'area': 22.5,
      'totalRooms': 4,
      'availableRooms': 2,
      'electricityPrice': 3000,
      'waterPrice': 12000,
      'internetPrice': 100000,
      'deposit': 4500000,
      'hasDeposit': held,
    });

    expect(withDeposit(true).hasDeposit, isTrue);
    expect(withDeposit(false).hasDeposit, isFalse);
  });
}
