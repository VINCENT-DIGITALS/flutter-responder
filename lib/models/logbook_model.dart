enum Sex { MALE, FEMALE }

class Details {
  String incidentNature;
  String incidentPlace;
  String name;
  Sex sex;
  int age;
  String address;
  String injury;
  String remarks;

  Details({
    required this.incidentNature,
    required this.incidentPlace,
    required this.name,
    required this.sex,
    required this.age,
    required this.address,
    required this.injury,
    required this.remarks,
  });

  // Add the toJson method to convert Details object to JSON
  Map<String, dynamic> toJson() {
    return {
      'incidentNature': incidentNature,
      'incidentPlace': incidentPlace,
      'name': name,
      'sex': sex.index,
      'age': age,
      'address': address,
      'injury': injury,
      'remarks': remarks,
    };
  }

  // Add the fromJson method to create a Details object from JSON
  static Details fromJson(Map<String, dynamic> json) {
    return Details(
      incidentNature: json['incidentNature'],
      incidentPlace: json['incidentPlace'],
      name: json['name'],
      sex: Sex.values[json['sex']],
      age: json['age'],
      address: json['address'],
      injury: json['injury'],
      remarks: json['remarks'],
    );
  }

  Details copyWith({
    String? incidentNature,
    String? incidentPlace,
    String? name,
    Sex? sex,
    int? age,
    String? address,
    String? injury,
    String? remarks,
  }) {
    return Details(
      incidentNature: incidentNature ?? this.incidentNature,
      incidentPlace: incidentPlace ?? this.incidentPlace,
      name: name ?? this.name,
      sex: sex ?? this.sex,
      age: age ?? this.age,
      address: address ?? this.address,
      injury: injury ?? this.injury,
      remarks: remarks ?? this.remarks,
    );
  }
}