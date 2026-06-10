import 'package:flutter/material.dart';

class ResponsiveTableColumn {
  const ResponsiveTableColumn({
    required this.label,
    required this.value,
    this.cell,
    this.minWidth = 140,
  });

  final String label;
  final String Function(Map<String, dynamic> row) value;
  final Widget Function(Map<String, dynamic> row)? cell;
  final double minWidth;
}

class ResponsiveTable extends StatelessWidget {
  const ResponsiveTable({
    super.key,
    required this.columns,
    required this.rows,
    this.actions,
  });

  final List<ResponsiveTableColumn> columns;
  final List<Map<String, dynamic>> rows;
  final Widget Function(Map<String, dynamic> row)? actions;

  @override
  Widget build(BuildContext context) {
    final tableWidth = columns.fold<double>(
        actions == null ? 0 : 124, (sum, column) => sum + column.minWidth);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth < constraints.maxWidth
                  ? constraints.maxWidth
                  : tableWidth,
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 14,
                    horizontalMargin: 18,
                    headingRowHeight: 48,
                    dataRowMinHeight: 58,
                    dataRowMaxHeight: 78,
                    dividerThickness: 1,
                    columns: [
                      ...columns.map((column) => DataColumn(
                            label: SizedBox(
                              width: column.minWidth - 18,
                              child: Text(
                                column.label.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )),
                      if (actions != null)
                        const DataColumn(
                            label: SizedBox(
                                width: 96,
                                child:
                                    Text('AKSI', textAlign: TextAlign.center))),
                    ],
                    rows: rows.indexed.map((entry) {
                      final row = entry.$2;
                      return DataRow(
                        color: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return const Color(0xFFF1F5FF);
                          }
                          return entry.$1.isEven
                              ? Colors.white
                              : const Color(0xFFFBFCFF);
                        }),
                        cells: [
                          ...columns.map((column) {
                            return DataCell(
                              SizedBox(
                                width: column.minWidth - 18,
                                child: column.cell?.call(row) ??
                                    Text(
                                      column.value(row),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Color(0xFF334155),
                                          fontWeight: FontWeight.w700,
                                          height: 1.25),
                                    ),
                              ),
                            );
                          }),
                          if (actions != null)
                            DataCell(SizedBox(
                                width: 96,
                                child: Center(child: actions!(row)))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
