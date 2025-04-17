import '../types/table.dart';
import '../utils/convertion_helper.dart';

import 'condition.dart';

class Dartonic extends QueryBuilder {
  Dartonic([List<TableSchema>? schemas]) : super(schemas ?? []);
}

class QueryBuilder {
  String _table = '';
  List<String> _columns = ['*'];
  final List<String> _whereClauses = [];
  final List<String> _orderByClauses = [];
  final List<String> _joinClauses = [];
  final List<String> _unionQueries = [];
  int? _limit;
  int? _offset;
  Map<String, dynamic> _insertData = {};
  Map<String, dynamic> _updateData = {};
  String? _queryType;
  final List<dynamic> _parameters = [];
  String? _createTableSQL;
  final List<String> _alterTableCommands = [];
  late final Map<String, TableSchema> _schemas;
  final List<String> _groupByClauses = [];
  final List<String> _havingClauses = [];

  String? _returningClause;

  QueryBuilder(List<TableSchema> schemas) {
    _schemas = {for (var schema in schemas) schema.name: schema};
  }

  String _escapeIdentifier(String identifier) {
    if (identifier.toLowerCase().contains('count')) {
      return identifier;
    }

    if (identifier.contains('.')) {
      return identifier.split('.').map((part) => '"$part"').join('.');
    }
    return '"$identifier"';
  }

  QueryBuilder select([Map<String, String>? columns]) {
    _queryType = 'SELECT';
    if (columns == null) {
      _columns = ['*'];
    } else {
      _columns = columns.entries
          .map((e) =>
              "${_escapeIdentifier(e.value)} AS ${_escapeIdentifier(e.key)}")
          .toList();
    }

    return this;
  }

  QueryBuilder from(String table) {
    _table = _escapeIdentifier(table);

    return this;
  }

  QueryBuilder groupBy(List<String> columns) {
    _groupByClauses.addAll(columns.map(_escapeIdentifier));

    return this;
  }

  QueryBuilder having(dynamic columnOrCondition,
      [String? operator, dynamic value]) {
    if (columnOrCondition is Condition) {
      _havingClauses.add(columnOrCondition.clause);
      _parameters.addAll(columnOrCondition.values);
    } else {
      _havingClauses.add("$columnOrCondition $operator ?");
      _parameters.add(value);
    }
    return this;
  }

  QueryBuilder where(dynamic columnOrCondition,
      [String? operator, dynamic value]) {
    if (columnOrCondition is Condition) {
      _whereClauses.add(columnOrCondition.clause);
      _parameters.addAll(columnOrCondition.values);
    } else {
      _whereClauses.add("$columnOrCondition $operator ?");
      _parameters.add(value);
    }
    return this;
  }

  QueryBuilder orderBy(String column, [String direction = 'ASC']) {
    _orderByClauses.add("${_escapeIdentifier(column)} $direction");

    return this;
  }

  QueryBuilder limit(int value) {
    _limit = value;
    return this;
  }

  QueryBuilder offset(int value) {
    _offset = value;
    return this;
  }

  QueryBuilder innerJoin(String table, Condition condition) {
    _joinClauses
        .add("INNER JOIN ${_escapeIdentifier(table)} ON ${condition.clause}");
    _parameters.addAll(condition.values);
    return this;
  }

  QueryBuilder leftJoin(String table, Condition condition) {
    _joinClauses
        .add("LEFT JOIN  ${_escapeIdentifier(table)} ON ${condition.clause}");
    _parameters.addAll(condition.values);
    return this;
  }

  QueryBuilder rightJoin(String table, Condition condition) {
    _joinClauses
        .add("RIGHT JOIN ${_escapeIdentifier(table)} ON ${condition.clause}");
    _parameters.addAll(condition.values);
    return this;
  }

  QueryBuilder fullJoin(String table, Condition condition) {
    _joinClauses
        .add("FULL JOIN ${_escapeIdentifier(table)} ON ${condition.clause}");
    _parameters.addAll(condition.values);
    return this;
  }

  QueryBuilder union(QueryBuilder otherQuery) {
    _unionQueries.add(otherQuery.toSql());
    return this;
  }

  QueryBuilder function(String function, String column, String alias) {
    _columns = [
      "$function(${_escapeIdentifier(column)}) AS ${_escapeIdentifier(alias)}"
    ];

    return this;
  }

  // Ajuste no método count:
  // Se houver condição, ela será adicionada à cláusula WHERE.
  // Além disso, não utilizamos alias para a função count, para que o retorno seja apenas o valor.
  QueryBuilder count([Condition? condition]) {
    _columns = ["COUNT(*)"];

    if (condition != null) {
      _whereClauses.add(condition.clause);
      _parameters.addAll(condition.values);
    }
    return this;
  }

  QueryBuilder insert(String table) {
    _table = _escapeIdentifier(table);
    _queryType = 'INSERT';
    return this;
  }

  QueryBuilder values(Map<String, dynamic> data) {
    _parameters.clear();

    final tableSchema = _schemas[_table];
    _insertData = {};
    data.forEach((key, value) {
      if (tableSchema != null && tableSchema.columns.containsKey(key)) {
        final colType = tableSchema.columns[key]!;
        _insertData[key] = convertValueForInsert(value, colType);
      } else {
        _insertData[key] = value;
      }
    });
    _parameters.addAll(_insertData.values);
    return this;
  }

  // Métodos para UPDATE
  QueryBuilder update(String table) {
    _table = _escapeIdentifier(table);
    _queryType = 'UPDATE';
    return this;
  }

  QueryBuilder set(Map<String, dynamic> data) {
    _updateData = Map<String, dynamic>.from(data);
    _parameters.addAll(_updateData.values);
    return this;
  }

  // Métodos para DELETE
  QueryBuilder delete(String table) {
    _table = _escapeIdentifier(table);
    _queryType = 'DELETE';
    return this;
  }

  // Método returning para inserir cláusula RETURNING em INSERT, UPDATE ou DELETE.
  QueryBuilder returning([List<String>? columns]) {
    if (columns == null || columns.isEmpty) {
      _returningClause = "RETURNING *";
    } else {
      if (columns.length == 1 && columns.first == '*') {
        _returningClause = "RETURNING *";
        return this;
      }

      final escapedColumns = columns.map(_escapeIdentifier).join(', ');
      _returningClause = "RETURNING $escapedColumns";
    }
    return this;
  }

  QueryBuilder returningId() {
    _returningClause = "RETURNING id";
    return this;
  }

  // Métodos para criação e alteração de tabelas
  QueryBuilder createTable(String table, Map<String, String> columns) {
    _queryType = 'CREATE_TABLE';
    _createTableSQL =
        "CREATE TABLE IF NOT EXISTS ${_escapeIdentifier(table)} (${columns.entries.map((e) => "${e.key} ${e.value}").join(', ')})";
    return this;
  }

  QueryBuilder dropTable(String table) {
    _queryType = 'DROP_TABLE';
    _table = _escapeIdentifier(table);
    return this;
  }

  QueryBuilder addColumn(String columnName, String columnType) {
    _alterTableCommands
        .add("ADD COLUMN ${_escapeIdentifier(columnName)} $columnType");
    return this;
  }

  QueryBuilder dropColumn(String columnName) {
    _alterTableCommands.add("DROP COLUMN ${_escapeIdentifier(columnName)}");
    return this;
  }

  /// Retorna a string SQL sem executar.
  String toSql() {
    var s = toString();
    if (s.isEmpty) {
      throw Exception('Nenhuma operação definida!');
    }
    return s;
  }

  @override
  String toString() {
    if (_queryType == 'SELECT') return _buildSelect();
    if (_queryType == 'INSERT') return _buildInsert();
    if (_queryType == 'UPDATE') return _buildUpdate();
    if (_queryType == 'DELETE') return _buildDelete();
    if (_queryType == 'CREATE_TABLE') return _createTableSQL!;
    if (_queryType == 'DROP_TABLE') return "DROP TABLE IF EXISTS $_table";
    if (_alterTableCommands.isNotEmpty) {
      return "ALTER TABLE $_table ${_alterTableCommands.join(", ")}";
    }
    return "";
  }

  List<dynamic> getParameters() => _parameters;

  String _buildSelect() {
    String sql = "SELECT ${_columns.join(', ')} FROM $_table";

    if (_joinClauses.isNotEmpty) {
      sql += " ${_joinClauses.join(" ")}";
    }

    if (_whereClauses.isNotEmpty) {
      sql += " WHERE ${_whereClauses.join(" AND ")}";
    }

    if (_groupByClauses.isNotEmpty) {
      sql += " GROUP BY ${_groupByClauses.join(", ")}";
    }

    if (_havingClauses.isNotEmpty) {
      sql += " HAVING ${_havingClauses.join(" AND ")}";
    }

    if (_orderByClauses.isNotEmpty) {
      sql += " ORDER BY ${_orderByClauses.join(", ")}";
    }

    if (_limit != null) {
      sql += " LIMIT $_limit";
    }

    if (_offset != null) {
      sql += " OFFSET $_offset";
    }

    if (_unionQueries.isNotEmpty) {
      sql += " UNION ${_unionQueries.join(" UNION ")}";
    }

    return sql;
  }

  String _buildInsert() {
    final columns = _insertData.keys.map(_escapeIdentifier).join(', ');
    final placeholders = List.filled(_insertData.length, '?').join(', ');
    String sql = "INSERT INTO $_table ($columns) VALUES ($placeholders)";
    if (_returningClause != null) {
      sql += " $_returningClause";
    }
    return sql;
  }

  String _buildUpdate() {
    final setClause = _updateData.keys
        .map((key) => "${_escapeIdentifier(key)} = ?")
        .join(", ");
    String sql = "UPDATE $_table SET $setClause";
    if (_whereClauses.isNotEmpty) {
      sql += " WHERE ${_whereClauses.join(" AND ")}";
    }

    if (_returningClause != null) {
      sql += " $_returningClause";
    }
    return sql;
  }

  String _buildDelete() {
    String sql = "DELETE FROM $_table";
    if (_whereClauses.isNotEmpty) {
      sql += " WHERE ${_whereClauses.join(" AND ")}";
    }

    if (_returningClause != null) {
      sql += " $_returningClause";
    }
    return sql;
  }

  QueryBuilder reset() {
    _table = '';
    _columns = ['*'];
    _whereClauses.clear();
    _orderByClauses.clear();
    _joinClauses.clear();
    _unionQueries.clear();
    _limit = null;
    _offset = null;
    _insertData.clear();
    _updateData.clear();
    _queryType = null;
    _parameters.clear();
    _createTableSQL = null;
    _alterTableCommands.clear();
    _returningClause = null;
    _groupByClauses.clear();
    _havingClauses.clear();
    return this;
  }
}
