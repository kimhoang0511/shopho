// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

OrderImage _$OrderImageFromJson(Map<String, dynamic> json) {
  return _OrderImage.fromJson(json);
}

/// @nodoc
mixin _$OrderImage {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'public_url')
  String get publicUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'sort_order')
  int get sortOrder => throw _privateConstructorUsedError;

  /// Serializes this OrderImage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderImage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderImageCopyWith<OrderImage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderImageCopyWith<$Res> {
  factory $OrderImageCopyWith(
          OrderImage value, $Res Function(OrderImage) then) =
      _$OrderImageCopyWithImpl<$Res, OrderImage>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'public_url') String publicUrl,
      @JsonKey(name: 'sort_order') int sortOrder});
}

/// @nodoc
class _$OrderImageCopyWithImpl<$Res, $Val extends OrderImage>
    implements $OrderImageCopyWith<$Res> {
  _$OrderImageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderImage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? publicUrl = null,
    Object? sortOrder = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      publicUrl: null == publicUrl
          ? _value.publicUrl
          : publicUrl // ignore: cast_nullable_to_non_nullable
              as String,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OrderImageImplCopyWith<$Res>
    implements $OrderImageCopyWith<$Res> {
  factory _$$OrderImageImplCopyWith(
          _$OrderImageImpl value, $Res Function(_$OrderImageImpl) then) =
      __$$OrderImageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'public_url') String publicUrl,
      @JsonKey(name: 'sort_order') int sortOrder});
}

/// @nodoc
class __$$OrderImageImplCopyWithImpl<$Res>
    extends _$OrderImageCopyWithImpl<$Res, _$OrderImageImpl>
    implements _$$OrderImageImplCopyWith<$Res> {
  __$$OrderImageImplCopyWithImpl(
      _$OrderImageImpl _value, $Res Function(_$OrderImageImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrderImage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? publicUrl = null,
    Object? sortOrder = null,
  }) {
    return _then(_$OrderImageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      publicUrl: null == publicUrl
          ? _value.publicUrl
          : publicUrl // ignore: cast_nullable_to_non_nullable
              as String,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderImageImpl implements _OrderImage {
  const _$OrderImageImpl(
      {required this.id,
      @JsonKey(name: 'public_url') required this.publicUrl,
      @JsonKey(name: 'sort_order') required this.sortOrder});

  factory _$OrderImageImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderImageImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'public_url')
  final String publicUrl;
  @override
  @JsonKey(name: 'sort_order')
  final int sortOrder;

  @override
  String toString() {
    return 'OrderImage(id: $id, publicUrl: $publicUrl, sortOrder: $sortOrder)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderImageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.publicUrl, publicUrl) ||
                other.publicUrl == publicUrl) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, publicUrl, sortOrder);

  /// Create a copy of OrderImage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderImageImplCopyWith<_$OrderImageImpl> get copyWith =>
      __$$OrderImageImplCopyWithImpl<_$OrderImageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderImageImplToJson(
      this,
    );
  }
}

abstract class _OrderImage implements OrderImage {
  const factory _OrderImage(
          {required final String id,
          @JsonKey(name: 'public_url') required final String publicUrl,
          @JsonKey(name: 'sort_order') required final int sortOrder}) =
      _$OrderImageImpl;

  factory _OrderImage.fromJson(Map<String, dynamic> json) =
      _$OrderImageImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'public_url')
  String get publicUrl;
  @override
  @JsonKey(name: 'sort_order')
  int get sortOrder;

  /// Create a copy of OrderImage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderImageImplCopyWith<_$OrderImageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OrderListItem _$OrderListItemFromJson(Map<String, dynamic> json) {
  return _OrderListItem.fromJson(json);
}

/// @nodoc
mixin _$OrderListItem {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'creator_id')
  String get creatorId => throw _privateConstructorUsedError;
  String get note => throw _privateConstructorUsedError;
  @JsonKey(name: 'gold_reward')
  double get goldReward => throw _privateConstructorUsedError;
  @JsonKey(name: 'ship_location')
  ShipLocationType get shipLocation => throw _privateConstructorUsedError;
  @JsonKey(name: 'ship_building')
  String? get shipBuilding => throw _privateConstructorUsedError;
  @JsonKey(name: 'ship_floor')
  int? get shipFloor => throw _privateConstructorUsedError;
  @JsonKey(name: 'ship_room')
  String? get shipRoom => throw _privateConstructorUsedError;
  @JsonKey(name: 'expires_at')
  DateTime get expiresAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  List<OrderImage> get images => throw _privateConstructorUsedError;
  @JsonKey(name: 'creator_building')
  String? get creatorBuilding => throw _privateConstructorUsedError;
  @JsonKey(name: 'ship_apartment_name')
  String? get shipApartmentName => throw _privateConstructorUsedError;

  /// Serializes this OrderListItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderListItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderListItemCopyWith<OrderListItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderListItemCopyWith<$Res> {
  factory $OrderListItemCopyWith(
          OrderListItem value, $Res Function(OrderListItem) then) =
      _$OrderListItemCopyWithImpl<$Res, OrderListItem>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'creator_id') String creatorId,
      String note,
      @JsonKey(name: 'gold_reward') double goldReward,
      @JsonKey(name: 'ship_location') ShipLocationType shipLocation,
      @JsonKey(name: 'ship_building') String? shipBuilding,
      @JsonKey(name: 'ship_floor') int? shipFloor,
      @JsonKey(name: 'ship_room') String? shipRoom,
      @JsonKey(name: 'expires_at') DateTime expiresAt,
      @JsonKey(name: 'created_at') DateTime createdAt,
      List<OrderImage> images,
      @JsonKey(name: 'creator_building') String? creatorBuilding,
      @JsonKey(name: 'ship_apartment_name') String? shipApartmentName});
}

/// @nodoc
class _$OrderListItemCopyWithImpl<$Res, $Val extends OrderListItem>
    implements $OrderListItemCopyWith<$Res> {
  _$OrderListItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderListItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? creatorId = null,
    Object? note = null,
    Object? goldReward = null,
    Object? shipLocation = null,
    Object? shipBuilding = freezed,
    Object? shipFloor = freezed,
    Object? shipRoom = freezed,
    Object? expiresAt = null,
    Object? createdAt = null,
    Object? images = null,
    Object? creatorBuilding = freezed,
    Object? shipApartmentName = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      creatorId: null == creatorId
          ? _value.creatorId
          : creatorId // ignore: cast_nullable_to_non_nullable
              as String,
      note: null == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
      goldReward: null == goldReward
          ? _value.goldReward
          : goldReward // ignore: cast_nullable_to_non_nullable
              as double,
      shipLocation: null == shipLocation
          ? _value.shipLocation
          : shipLocation // ignore: cast_nullable_to_non_nullable
              as ShipLocationType,
      shipBuilding: freezed == shipBuilding
          ? _value.shipBuilding
          : shipBuilding // ignore: cast_nullable_to_non_nullable
              as String?,
      shipFloor: freezed == shipFloor
          ? _value.shipFloor
          : shipFloor // ignore: cast_nullable_to_non_nullable
              as int?,
      shipRoom: freezed == shipRoom
          ? _value.shipRoom
          : shipRoom // ignore: cast_nullable_to_non_nullable
              as String?,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<OrderImage>,
      creatorBuilding: freezed == creatorBuilding
          ? _value.creatorBuilding
          : creatorBuilding // ignore: cast_nullable_to_non_nullable
              as String?,
      shipApartmentName: freezed == shipApartmentName
          ? _value.shipApartmentName
          : shipApartmentName // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OrderListItemImplCopyWith<$Res>
    implements $OrderListItemCopyWith<$Res> {
  factory _$$OrderListItemImplCopyWith(
          _$OrderListItemImpl value, $Res Function(_$OrderListItemImpl) then) =
      __$$OrderListItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'creator_id') String creatorId,
      String note,
      @JsonKey(name: 'gold_reward') double goldReward,
      @JsonKey(name: 'ship_location') ShipLocationType shipLocation,
      @JsonKey(name: 'ship_building') String? shipBuilding,
      @JsonKey(name: 'ship_floor') int? shipFloor,
      @JsonKey(name: 'ship_room') String? shipRoom,
      @JsonKey(name: 'expires_at') DateTime expiresAt,
      @JsonKey(name: 'created_at') DateTime createdAt,
      List<OrderImage> images,
      @JsonKey(name: 'creator_building') String? creatorBuilding,
      @JsonKey(name: 'ship_apartment_name') String? shipApartmentName});
}

/// @nodoc
class __$$OrderListItemImplCopyWithImpl<$Res>
    extends _$OrderListItemCopyWithImpl<$Res, _$OrderListItemImpl>
    implements _$$OrderListItemImplCopyWith<$Res> {
  __$$OrderListItemImplCopyWithImpl(
      _$OrderListItemImpl _value, $Res Function(_$OrderListItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrderListItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? creatorId = null,
    Object? note = null,
    Object? goldReward = null,
    Object? shipLocation = null,
    Object? shipBuilding = freezed,
    Object? shipFloor = freezed,
    Object? shipRoom = freezed,
    Object? expiresAt = null,
    Object? createdAt = null,
    Object? images = null,
    Object? creatorBuilding = freezed,
    Object? shipApartmentName = freezed,
  }) {
    return _then(_$OrderListItemImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      creatorId: null == creatorId
          ? _value.creatorId
          : creatorId // ignore: cast_nullable_to_non_nullable
              as String,
      note: null == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
      goldReward: null == goldReward
          ? _value.goldReward
          : goldReward // ignore: cast_nullable_to_non_nullable
              as double,
      shipLocation: null == shipLocation
          ? _value.shipLocation
          : shipLocation // ignore: cast_nullable_to_non_nullable
              as ShipLocationType,
      shipBuilding: freezed == shipBuilding
          ? _value.shipBuilding
          : shipBuilding // ignore: cast_nullable_to_non_nullable
              as String?,
      shipFloor: freezed == shipFloor
          ? _value.shipFloor
          : shipFloor // ignore: cast_nullable_to_non_nullable
              as int?,
      shipRoom: freezed == shipRoom
          ? _value.shipRoom
          : shipRoom // ignore: cast_nullable_to_non_nullable
              as String?,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<OrderImage>,
      creatorBuilding: freezed == creatorBuilding
          ? _value.creatorBuilding
          : creatorBuilding // ignore: cast_nullable_to_non_nullable
              as String?,
      shipApartmentName: freezed == shipApartmentName
          ? _value.shipApartmentName
          : shipApartmentName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderListItemImpl implements _OrderListItem {
  const _$OrderListItemImpl(
      {required this.id,
      @JsonKey(name: 'creator_id') required this.creatorId,
      required this.note,
      @JsonKey(name: 'gold_reward') required this.goldReward,
      @JsonKey(name: 'ship_location') required this.shipLocation,
      @JsonKey(name: 'ship_building') this.shipBuilding,
      @JsonKey(name: 'ship_floor') this.shipFloor,
      @JsonKey(name: 'ship_room') this.shipRoom,
      @JsonKey(name: 'expires_at') required this.expiresAt,
      @JsonKey(name: 'created_at') required this.createdAt,
      required final List<OrderImage> images,
      @JsonKey(name: 'creator_building') this.creatorBuilding,
      @JsonKey(name: 'ship_apartment_name') this.shipApartmentName})
      : _images = images;

  factory _$OrderListItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderListItemImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'creator_id')
  final String creatorId;
  @override
  final String note;
  @override
  @JsonKey(name: 'gold_reward')
  final double goldReward;
  @override
  @JsonKey(name: 'ship_location')
  final ShipLocationType shipLocation;
  @override
  @JsonKey(name: 'ship_building')
  final String? shipBuilding;
  @override
  @JsonKey(name: 'ship_floor')
  final int? shipFloor;
  @override
  @JsonKey(name: 'ship_room')
  final String? shipRoom;
  @override
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  final List<OrderImage> _images;
  @override
  List<OrderImage> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  @JsonKey(name: 'creator_building')
  final String? creatorBuilding;
  @override
  @JsonKey(name: 'ship_apartment_name')
  final String? shipApartmentName;

  @override
  String toString() {
    return 'OrderListItem(id: $id, creatorId: $creatorId, note: $note, goldReward: $goldReward, shipLocation: $shipLocation, shipBuilding: $shipBuilding, shipFloor: $shipFloor, shipRoom: $shipRoom, expiresAt: $expiresAt, createdAt: $createdAt, images: $images, creatorBuilding: $creatorBuilding, shipApartmentName: $shipApartmentName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderListItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.creatorId, creatorId) ||
                other.creatorId == creatorId) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.goldReward, goldReward) ||
                other.goldReward == goldReward) &&
            (identical(other.shipLocation, shipLocation) ||
                other.shipLocation == shipLocation) &&
            (identical(other.shipBuilding, shipBuilding) ||
                other.shipBuilding == shipBuilding) &&
            (identical(other.shipFloor, shipFloor) ||
                other.shipFloor == shipFloor) &&
            (identical(other.shipRoom, shipRoom) ||
                other.shipRoom == shipRoom) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.creatorBuilding, creatorBuilding) ||
                other.creatorBuilding == creatorBuilding) &&
            (identical(other.shipApartmentName, shipApartmentName) ||
                other.shipApartmentName == shipApartmentName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      creatorId,
      note,
      goldReward,
      shipLocation,
      shipBuilding,
      shipFloor,
      shipRoom,
      expiresAt,
      createdAt,
      const DeepCollectionEquality().hash(_images),
      creatorBuilding,
      shipApartmentName);

  /// Create a copy of OrderListItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderListItemImplCopyWith<_$OrderListItemImpl> get copyWith =>
      __$$OrderListItemImplCopyWithImpl<_$OrderListItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderListItemImplToJson(
      this,
    );
  }
}

abstract class _OrderListItem implements OrderListItem {
  const factory _OrderListItem(
      {required final String id,
      @JsonKey(name: 'creator_id') required final String creatorId,
      required final String note,
      @JsonKey(name: 'gold_reward') required final double goldReward,
      @JsonKey(name: 'ship_location')
      required final ShipLocationType shipLocation,
      @JsonKey(name: 'ship_building') final String? shipBuilding,
      @JsonKey(name: 'ship_floor') final int? shipFloor,
      @JsonKey(name: 'ship_room') final String? shipRoom,
      @JsonKey(name: 'expires_at') required final DateTime expiresAt,
      @JsonKey(name: 'created_at') required final DateTime createdAt,
      required final List<OrderImage> images,
      @JsonKey(name: 'creator_building') final String? creatorBuilding,
      @JsonKey(name: 'ship_apartment_name')
      final String? shipApartmentName}) = _$OrderListItemImpl;

  factory _OrderListItem.fromJson(Map<String, dynamic> json) =
      _$OrderListItemImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'creator_id')
  String get creatorId;
  @override
  String get note;
  @override
  @JsonKey(name: 'gold_reward')
  double get goldReward;
  @override
  @JsonKey(name: 'ship_location')
  ShipLocationType get shipLocation;
  @override
  @JsonKey(name: 'ship_building')
  String? get shipBuilding;
  @override
  @JsonKey(name: 'ship_floor')
  int? get shipFloor;
  @override
  @JsonKey(name: 'ship_room')
  String? get shipRoom;
  @override
  @JsonKey(name: 'expires_at')
  DateTime get expiresAt;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  List<OrderImage> get images;
  @override
  @JsonKey(name: 'creator_building')
  String? get creatorBuilding;
  @override
  @JsonKey(name: 'ship_apartment_name')
  String? get shipApartmentName;

  /// Create a copy of OrderListItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderListItemImplCopyWith<_$OrderListItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OrderDetail _$OrderDetailFromJson(Map<String, dynamic> json) {
  return _OrderDetail.fromJson(json);
}

/// @nodoc
mixin _$OrderDetail {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'creator_id')
  String get creatorId => throw _privateConstructorUsedError;
  @JsonKey(name: 'shipper_id')
  String? get shipperId => throw _privateConstructorUsedError;
  String get note => throw _privateConstructorUsedError;
  @JsonKey(name: 'gold_reward')
  double get goldReward => throw _privateConstructorUsedError;
  @JsonKey(name: 'ship_location')
  ShipLocationType get shipLocation => throw _privateConstructorUsedError;
  @JsonKey(name: 'ship_building')
  String? get shipBuilding => throw _privateConstructorUsedError;
  @JsonKey(name: 'ship_floor')
  int? get shipFloor => throw _privateConstructorUsedError;
  @JsonKey(name: 'ship_room')
  String? get shipRoom => throw _privateConstructorUsedError;
  @JsonKey(name: 'validity_option')
  String get validityOption => throw _privateConstructorUsedError;
  @JsonKey(name: 'expires_at')
  DateTime get expiresAt => throw _privateConstructorUsedError;
  OrderStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'accepted_at')
  DateTime? get acceptedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'completed_at')
  DateTime? get completedAt => throw _privateConstructorUsedError;
  List<OrderImage> get images => throw _privateConstructorUsedError;
  @JsonKey(name: 'ship_apartment_name')
  String? get shipApartmentName => throw _privateConstructorUsedError;
  @JsonKey(name: 'estimated_minutes')
  int? get estimatedMinutes => throw _privateConstructorUsedError;
  @JsonKey(name: 'estimated_delivery_at')
  DateTime? get estimatedDeliveryAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'min_proposed_gold')
  double? get minProposedGold => throw _privateConstructorUsedError;

  /// Serializes this OrderDetail to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderDetailCopyWith<OrderDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderDetailCopyWith<$Res> {
  factory $OrderDetailCopyWith(
          OrderDetail value, $Res Function(OrderDetail) then) =
      _$OrderDetailCopyWithImpl<$Res, OrderDetail>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'creator_id') String creatorId,
      @JsonKey(name: 'shipper_id') String? shipperId,
      String note,
      @JsonKey(name: 'gold_reward') double goldReward,
      @JsonKey(name: 'ship_location') ShipLocationType shipLocation,
      @JsonKey(name: 'ship_building') String? shipBuilding,
      @JsonKey(name: 'ship_floor') int? shipFloor,
      @JsonKey(name: 'ship_room') String? shipRoom,
      @JsonKey(name: 'validity_option') String validityOption,
      @JsonKey(name: 'expires_at') DateTime expiresAt,
      OrderStatus status,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'accepted_at') DateTime? acceptedAt,
      @JsonKey(name: 'completed_at') DateTime? completedAt,
      List<OrderImage> images,
      @JsonKey(name: 'ship_apartment_name') String? shipApartmentName,
      @JsonKey(name: 'estimated_minutes') int? estimatedMinutes,
      @JsonKey(name: 'estimated_delivery_at') DateTime? estimatedDeliveryAt,
      @JsonKey(name: 'min_proposed_gold') double? minProposedGold});
}

/// @nodoc
class _$OrderDetailCopyWithImpl<$Res, $Val extends OrderDetail>
    implements $OrderDetailCopyWith<$Res> {
  _$OrderDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? creatorId = null,
    Object? shipperId = freezed,
    Object? note = null,
    Object? goldReward = null,
    Object? shipLocation = null,
    Object? shipBuilding = freezed,
    Object? shipFloor = freezed,
    Object? shipRoom = freezed,
    Object? validityOption = null,
    Object? expiresAt = null,
    Object? status = null,
    Object? createdAt = null,
    Object? acceptedAt = freezed,
    Object? completedAt = freezed,
    Object? images = null,
    Object? shipApartmentName = freezed,
    Object? estimatedMinutes = freezed,
    Object? estimatedDeliveryAt = freezed,
    Object? minProposedGold = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      creatorId: null == creatorId
          ? _value.creatorId
          : creatorId // ignore: cast_nullable_to_non_nullable
              as String,
      shipperId: freezed == shipperId
          ? _value.shipperId
          : shipperId // ignore: cast_nullable_to_non_nullable
              as String?,
      note: null == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
      goldReward: null == goldReward
          ? _value.goldReward
          : goldReward // ignore: cast_nullable_to_non_nullable
              as double,
      shipLocation: null == shipLocation
          ? _value.shipLocation
          : shipLocation // ignore: cast_nullable_to_non_nullable
              as ShipLocationType,
      shipBuilding: freezed == shipBuilding
          ? _value.shipBuilding
          : shipBuilding // ignore: cast_nullable_to_non_nullable
              as String?,
      shipFloor: freezed == shipFloor
          ? _value.shipFloor
          : shipFloor // ignore: cast_nullable_to_non_nullable
              as int?,
      shipRoom: freezed == shipRoom
          ? _value.shipRoom
          : shipRoom // ignore: cast_nullable_to_non_nullable
              as String?,
      validityOption: null == validityOption
          ? _value.validityOption
          : validityOption // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as OrderStatus,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      acceptedAt: freezed == acceptedAt
          ? _value.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<OrderImage>,
      shipApartmentName: freezed == shipApartmentName
          ? _value.shipApartmentName
          : shipApartmentName // ignore: cast_nullable_to_non_nullable
              as String?,
      estimatedMinutes: freezed == estimatedMinutes
          ? _value.estimatedMinutes
          : estimatedMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      estimatedDeliveryAt: freezed == estimatedDeliveryAt
          ? _value.estimatedDeliveryAt
          : estimatedDeliveryAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      minProposedGold: freezed == minProposedGold
          ? _value.minProposedGold
          : minProposedGold // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OrderDetailImplCopyWith<$Res>
    implements $OrderDetailCopyWith<$Res> {
  factory _$$OrderDetailImplCopyWith(
          _$OrderDetailImpl value, $Res Function(_$OrderDetailImpl) then) =
      __$$OrderDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'creator_id') String creatorId,
      @JsonKey(name: 'shipper_id') String? shipperId,
      String note,
      @JsonKey(name: 'gold_reward') double goldReward,
      @JsonKey(name: 'ship_location') ShipLocationType shipLocation,
      @JsonKey(name: 'ship_building') String? shipBuilding,
      @JsonKey(name: 'ship_floor') int? shipFloor,
      @JsonKey(name: 'ship_room') String? shipRoom,
      @JsonKey(name: 'validity_option') String validityOption,
      @JsonKey(name: 'expires_at') DateTime expiresAt,
      OrderStatus status,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'accepted_at') DateTime? acceptedAt,
      @JsonKey(name: 'completed_at') DateTime? completedAt,
      List<OrderImage> images,
      @JsonKey(name: 'ship_apartment_name') String? shipApartmentName,
      @JsonKey(name: 'estimated_minutes') int? estimatedMinutes,
      @JsonKey(name: 'estimated_delivery_at') DateTime? estimatedDeliveryAt,
      @JsonKey(name: 'min_proposed_gold') double? minProposedGold});
}

/// @nodoc
class __$$OrderDetailImplCopyWithImpl<$Res>
    extends _$OrderDetailCopyWithImpl<$Res, _$OrderDetailImpl>
    implements _$$OrderDetailImplCopyWith<$Res> {
  __$$OrderDetailImplCopyWithImpl(
      _$OrderDetailImpl _value, $Res Function(_$OrderDetailImpl) _then)
      : super(_value, _then);

  /// Create a copy of OrderDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? creatorId = null,
    Object? shipperId = freezed,
    Object? note = null,
    Object? goldReward = null,
    Object? shipLocation = null,
    Object? shipBuilding = freezed,
    Object? shipFloor = freezed,
    Object? shipRoom = freezed,
    Object? validityOption = null,
    Object? expiresAt = null,
    Object? status = null,
    Object? createdAt = null,
    Object? acceptedAt = freezed,
    Object? completedAt = freezed,
    Object? images = null,
    Object? shipApartmentName = freezed,
    Object? estimatedMinutes = freezed,
    Object? estimatedDeliveryAt = freezed,
    Object? minProposedGold = freezed,
  }) {
    return _then(_$OrderDetailImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      creatorId: null == creatorId
          ? _value.creatorId
          : creatorId // ignore: cast_nullable_to_non_nullable
              as String,
      shipperId: freezed == shipperId
          ? _value.shipperId
          : shipperId // ignore: cast_nullable_to_non_nullable
              as String?,
      note: null == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String,
      goldReward: null == goldReward
          ? _value.goldReward
          : goldReward // ignore: cast_nullable_to_non_nullable
              as double,
      shipLocation: null == shipLocation
          ? _value.shipLocation
          : shipLocation // ignore: cast_nullable_to_non_nullable
              as ShipLocationType,
      shipBuilding: freezed == shipBuilding
          ? _value.shipBuilding
          : shipBuilding // ignore: cast_nullable_to_non_nullable
              as String?,
      shipFloor: freezed == shipFloor
          ? _value.shipFloor
          : shipFloor // ignore: cast_nullable_to_non_nullable
              as int?,
      shipRoom: freezed == shipRoom
          ? _value.shipRoom
          : shipRoom // ignore: cast_nullable_to_non_nullable
              as String?,
      validityOption: null == validityOption
          ? _value.validityOption
          : validityOption // ignore: cast_nullable_to_non_nullable
              as String,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as OrderStatus,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      acceptedAt: freezed == acceptedAt
          ? _value.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<OrderImage>,
      shipApartmentName: freezed == shipApartmentName
          ? _value.shipApartmentName
          : shipApartmentName // ignore: cast_nullable_to_non_nullable
              as String?,
      estimatedMinutes: freezed == estimatedMinutes
          ? _value.estimatedMinutes
          : estimatedMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      estimatedDeliveryAt: freezed == estimatedDeliveryAt
          ? _value.estimatedDeliveryAt
          : estimatedDeliveryAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      minProposedGold: freezed == minProposedGold
          ? _value.minProposedGold
          : minProposedGold // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderDetailImpl implements _OrderDetail {
  const _$OrderDetailImpl(
      {required this.id,
      @JsonKey(name: 'creator_id') required this.creatorId,
      @JsonKey(name: 'shipper_id') this.shipperId,
      required this.note,
      @JsonKey(name: 'gold_reward') required this.goldReward,
      @JsonKey(name: 'ship_location') required this.shipLocation,
      @JsonKey(name: 'ship_building') this.shipBuilding,
      @JsonKey(name: 'ship_floor') this.shipFloor,
      @JsonKey(name: 'ship_room') this.shipRoom,
      @JsonKey(name: 'validity_option') required this.validityOption,
      @JsonKey(name: 'expires_at') required this.expiresAt,
      required this.status,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'accepted_at') this.acceptedAt,
      @JsonKey(name: 'completed_at') this.completedAt,
      required final List<OrderImage> images,
      @JsonKey(name: 'ship_apartment_name') this.shipApartmentName,
      @JsonKey(name: 'estimated_minutes') this.estimatedMinutes,
      @JsonKey(name: 'estimated_delivery_at') this.estimatedDeliveryAt,
      @JsonKey(name: 'min_proposed_gold') this.minProposedGold})
      : _images = images;

  factory _$OrderDetailImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderDetailImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'creator_id')
  final String creatorId;
  @override
  @JsonKey(name: 'shipper_id')
  final String? shipperId;
  @override
  final String note;
  @override
  @JsonKey(name: 'gold_reward')
  final double goldReward;
  @override
  @JsonKey(name: 'ship_location')
  final ShipLocationType shipLocation;
  @override
  @JsonKey(name: 'ship_building')
  final String? shipBuilding;
  @override
  @JsonKey(name: 'ship_floor')
  final int? shipFloor;
  @override
  @JsonKey(name: 'ship_room')
  final String? shipRoom;
  @override
  @JsonKey(name: 'validity_option')
  final String validityOption;
  @override
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  @override
  final OrderStatus status;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'accepted_at')
  final DateTime? acceptedAt;
  @override
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  final List<OrderImage> _images;
  @override
  List<OrderImage> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  @JsonKey(name: 'ship_apartment_name')
  final String? shipApartmentName;
  @override
  @JsonKey(name: 'estimated_minutes')
  final int? estimatedMinutes;
  @override
  @JsonKey(name: 'estimated_delivery_at')
  final DateTime? estimatedDeliveryAt;
  @override
  @JsonKey(name: 'min_proposed_gold')
  final double? minProposedGold;

  @override
  String toString() {
    return 'OrderDetail(id: $id, creatorId: $creatorId, shipperId: $shipperId, note: $note, goldReward: $goldReward, shipLocation: $shipLocation, shipBuilding: $shipBuilding, shipFloor: $shipFloor, shipRoom: $shipRoom, validityOption: $validityOption, expiresAt: $expiresAt, status: $status, createdAt: $createdAt, acceptedAt: $acceptedAt, completedAt: $completedAt, images: $images, shipApartmentName: $shipApartmentName, estimatedMinutes: $estimatedMinutes, estimatedDeliveryAt: $estimatedDeliveryAt, minProposedGold: $minProposedGold)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderDetailImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.creatorId, creatorId) ||
                other.creatorId == creatorId) &&
            (identical(other.shipperId, shipperId) ||
                other.shipperId == shipperId) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.goldReward, goldReward) ||
                other.goldReward == goldReward) &&
            (identical(other.shipLocation, shipLocation) ||
                other.shipLocation == shipLocation) &&
            (identical(other.shipBuilding, shipBuilding) ||
                other.shipBuilding == shipBuilding) &&
            (identical(other.shipFloor, shipFloor) ||
                other.shipFloor == shipFloor) &&
            (identical(other.shipRoom, shipRoom) ||
                other.shipRoom == shipRoom) &&
            (identical(other.validityOption, validityOption) ||
                other.validityOption == validityOption) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.shipApartmentName, shipApartmentName) ||
                other.shipApartmentName == shipApartmentName) &&
            (identical(other.estimatedMinutes, estimatedMinutes) ||
                other.estimatedMinutes == estimatedMinutes) &&
            (identical(other.estimatedDeliveryAt, estimatedDeliveryAt) ||
                other.estimatedDeliveryAt == estimatedDeliveryAt) &&
            (identical(other.minProposedGold, minProposedGold) ||
                other.minProposedGold == minProposedGold));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        creatorId,
        shipperId,
        note,
        goldReward,
        shipLocation,
        shipBuilding,
        shipFloor,
        shipRoom,
        validityOption,
        expiresAt,
        status,
        createdAt,
        acceptedAt,
        completedAt,
        const DeepCollectionEquality().hash(_images),
        shipApartmentName,
        estimatedMinutes,
        estimatedDeliveryAt,
        minProposedGold
      ]);

  /// Create a copy of OrderDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderDetailImplCopyWith<_$OrderDetailImpl> get copyWith =>
      __$$OrderDetailImplCopyWithImpl<_$OrderDetailImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderDetailImplToJson(
      this,
    );
  }
}

abstract class _OrderDetail implements OrderDetail {
  const factory _OrderDetail(
      {required final String id,
      @JsonKey(name: 'creator_id') required final String creatorId,
      @JsonKey(name: 'shipper_id') final String? shipperId,
      required final String note,
      @JsonKey(name: 'gold_reward') required final double goldReward,
      @JsonKey(name: 'ship_location')
      required final ShipLocationType shipLocation,
      @JsonKey(name: 'ship_building') final String? shipBuilding,
      @JsonKey(name: 'ship_floor') final int? shipFloor,
      @JsonKey(name: 'ship_room') final String? shipRoom,
      @JsonKey(name: 'validity_option') required final String validityOption,
      @JsonKey(name: 'expires_at') required final DateTime expiresAt,
      required final OrderStatus status,
      @JsonKey(name: 'created_at') required final DateTime createdAt,
      @JsonKey(name: 'accepted_at') final DateTime? acceptedAt,
      @JsonKey(name: 'completed_at') final DateTime? completedAt,
      required final List<OrderImage> images,
      @JsonKey(name: 'ship_apartment_name') final String? shipApartmentName,
      @JsonKey(name: 'estimated_minutes') final int? estimatedMinutes,
      @JsonKey(name: 'estimated_delivery_at')
      final DateTime? estimatedDeliveryAt,
      @JsonKey(name: 'min_proposed_gold')
      final double? minProposedGold}) = _$OrderDetailImpl;

  factory _OrderDetail.fromJson(Map<String, dynamic> json) =
      _$OrderDetailImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'creator_id')
  String get creatorId;
  @override
  @JsonKey(name: 'shipper_id')
  String? get shipperId;
  @override
  String get note;
  @override
  @JsonKey(name: 'gold_reward')
  double get goldReward;
  @override
  @JsonKey(name: 'ship_location')
  ShipLocationType get shipLocation;
  @override
  @JsonKey(name: 'ship_building')
  String? get shipBuilding;
  @override
  @JsonKey(name: 'ship_floor')
  int? get shipFloor;
  @override
  @JsonKey(name: 'ship_room')
  String? get shipRoom;
  @override
  @JsonKey(name: 'validity_option')
  String get validityOption;
  @override
  @JsonKey(name: 'expires_at')
  DateTime get expiresAt;
  @override
  OrderStatus get status;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'accepted_at')
  DateTime? get acceptedAt;
  @override
  @JsonKey(name: 'completed_at')
  DateTime? get completedAt;
  @override
  List<OrderImage> get images;
  @override
  @JsonKey(name: 'ship_apartment_name')
  String? get shipApartmentName;
  @override
  @JsonKey(name: 'estimated_minutes')
  int? get estimatedMinutes;
  @override
  @JsonKey(name: 'estimated_delivery_at')
  DateTime? get estimatedDeliveryAt;
  @override
  @JsonKey(name: 'min_proposed_gold')
  double? get minProposedGold;

  /// Create a copy of OrderDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderDetailImplCopyWith<_$OrderDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
