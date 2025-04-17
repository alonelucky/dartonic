import 'package:dartonic/dartonic.dart';

void main() {
  final usersTable = sqliteTable('users', {
    'id': integer().primaryKey(autoIncrement: true),
    'name': text().notNull(),
    'email': text().notNull().unique(),
  });

  final rolesTable = sqliteTable('roles', {
    'id': integer().primaryKey(autoIncrement: true),
    'name': text().notNull(),
    'created_at': datetime().defaultNow(),
  });

  final userRolesTable = sqliteTable(
    'user_roles',
    {
      'user_id': integer().notNull(),
      'role_id': integer().notNull(),
      'created_at': datetime().defaultNow(),
    },
    foreignKeys: [
      ForeignKey(
        column: 'user_id',
        references: 'users',
        referencesColumn: 'id',
        onDelete: ReferentialAction.cascade,
      ),
      ForeignKey(
        column: 'role_id',
        references: 'roles',
        referencesColumn: 'id',
        onDelete: ReferentialAction.cascade,
      ),
    ],
  );

  final db = QueryBuilder([
    usersTable,
    rolesTable,
    userRolesTable,
  ]);

  // Inserir mais dados de teste
  final user = db.insert('users').values({
    'name': 'Jane Doe',
    'email': 'janedoe@mail.com',
  }).returning();

  db.insert('users').values({
    'name': 'John Doe',
    'email': 'johndoe@mail.com',
  });
  print('Insert with returning: $user');
  // Insert with returning: INSERT INTO "users" ("name", "email") VALUES (?, ?) RETURNING *

  db.insert('roles').values({'name': 'user'});
  db.insert('roles').values({'name': 'admin'});

  // Criar mais relacionamentos
  db.insert('user_roles').values({
    'user_id': 2, // John Doe
    'role_id': 2, // role user
  });

  db.insert('user_roles').values({
    'user_id': 2, // Jane Doe
    'role_id': 1, // role admin
  });

  // Primeiro vamos garantir que o count está funcionando corretamente
  // Primeiro, confirmamos que temos 2 roles no sistema
  final userNameLikeJohn =
      db.select().from('users').where(like('users.name', '%john%'));
  print('Select with where like: $userNameLikeJohn');
  // Select with where like: SELECT * FROM "users" WHERE users.name LIKE ?

  // Query para buscar usuários e suas roles
  final usersWithRoles = db
      .select({
        'name': 'users.name',
        'total_roles': count(
          'user_roles.role_id',
          distinct: true,
        ), // sql('COUNT(DISTINCT user_roles.role_id)'),
      })
      .from('users')
      .innerJoin('user_roles', eq('users.id', 'user_roles.user_id'))
      .groupBy(['users.id', 'users.name']);
  print('Usuários e suas roles: $usersWithRoles');
  // Usuários e suas roles: SELECT "users"."name" AS "name", COUNT(DISTINCT user_roles.role_id) AS "total_roles" FROM "users" INNER JOIN "user_roles" ON "users"."id" = "user_roles"."user_id" WHERE users.name LIKE ? GROUP BY "users"."id", "users"."name"

  final userUpdate = db
      .update('users')
      .set({'name': 'John Doe Updated'})
      .where(eq('id', 1))
      .returning();
  print(userUpdate);
  // UPDATE "users" SET "name" = ? WHERE users.name LIKE ? AND "id" = 1 RETURNING *

  final usersCount = db.select().from('users').count();
  print('Total de usuários: ${usersCount.toString()}');
  // Total de usuários: SELECT COUNT(*) FROM "users" INNER JOIN "user_roles" ON "users"."id" = "user_roles"."user_id" WHERE users.name LIKE ? AND "id" = 1 GROUP BY "users"."id", "users"."name"

  //  db.delete('users').where(eq('users.id', 1));
}
