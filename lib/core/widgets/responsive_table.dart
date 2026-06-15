import 'dart:ui';
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

class ResponsiveTable extends StatefulWidget {
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
  State<ResponsiveTable> createState() => _ResponsiveTableState();
}

class _ResponsiveTableState extends State<ResponsiveTable> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableWidth = widget.columns.fold<double>(
        widget.actions == null ? 0 : 188, (sum, column) => sum + column.minWidth);

    return LayoutBuilder(
      builder: (context, constraints) {
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              ...ScrollConfiguration.of(context).dragDevices,
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
              PointerDeviceKind.trackpad,
            },
          ),
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth < constraints.maxWidth
                    ? constraints.maxWidth
                    : tableWidth,
                child: Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    child: DataTable(
                    columnSpacing: 14,
                    horizontalMargin: 18,
                    headingRowHeight: 48,
                    dataRowMinHeight: 58,
                    dataRowMaxHeight: 78,
                    dividerThickness: 1,
                    columns: [
                      ...widget.columns.map((column) => DataColumn(
                            label: SizedBox(
                              width: column.minWidth - 18,
                              child: Text(
                                column.label.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )),
                      if (widget.actions != null)
                        const DataColumn(
                            label: SizedBox(
                                width: 160,
                                child:
                                    Text('AKSI', textAlign: TextAlign.center))),
                    ],
                    rows: widget.rows.indexed.map((entry) {
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
                          ...widget.columns.map((column) {
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
                          if (widget.actions != null)
                            DataCell(SizedBox(
                                width: 160,
                                child: Center(child: widget.actions!(row)))),
                        ],
                      );
                    }).toList(),
                  ),
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
