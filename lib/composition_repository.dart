import '../models/composition.dart';

abstract class CompositionRepository {
  /// Returns all compositions ordered by last edited (newest first).
  Future<List<Composition>> loadAll();

  /// Saves a composition.
  /// If it already exists, it is updated.
  Future<void> save(Composition composition);

  /// Loads one composition by its id.
  Future<Composition?> load(int id);

  /// Deletes a composition.
  Future<void> delete(int id);

  /// Renames a composition.
  Future<void> rename(int id, String newTitle);

  /// Updates an existing composition.
  Future<void> update(Composition composition);

  /// Removes every composition.
  Future<void> clear();

}