import 'package:dartonic/dartonic.dart';

void main() {
  var db = Dartonic();
  var sql = db.select().from("table").where(eq("id", "aaaa"));
  print(sql);
}
