/// Generic paginated result wrapper.
class PaginatedResult<T> {
  final List<T> items;
  final int totalCount;
  final int page;
  final int perPage;

  const PaginatedResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.perPage,
  });

  int get totalPages => (totalCount / perPage).ceil();
  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
}
