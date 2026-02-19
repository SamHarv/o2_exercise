import 'package:flutter/material.dart';

import '../../utils/constants.dart';

class ExerciseInputWidget extends StatefulWidget {
  final int value;
  final String suffix;
  final double width;
  final void Function()? onTapPlus;
  final void Function()? onLongPressPlus;
  final void Function()? onTapMinus;
  final void Function()? onLongPressMinus;

  const ExerciseInputWidget({
    super.key,
    required this.value,
    required this.suffix,
    required this.width,
    this.onTapPlus,
    this.onLongPressPlus,
    this.onTapMinus,
    this.onLongPressMinus,
  });

  @override
  State<ExerciseInputWidget> createState() => _ExerciseInputWidgetState();
}

class _ExerciseInputWidgetState extends State<ExerciseInputWidget> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // constraints: BoxConstraints(), //maxWidth: widget.width / 3 - 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                '${widget.value}',
                style: TextStyle(color: white, fontSize: 14),
              ),
              SizedBox(width: 4),
              Text(widget.suffix, style: TextStyle(color: white, fontSize: 12)),
            ],
          ),
          SizedBox(width: 8),
          Column(
            children: [
              SizedBox(
                height: 40,
                width: 40,
                child: InkWell(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(8),
                    bottom: Radius.circular(0),
                  ),
                  onTap: widget.onTapPlus,
                  onLongPress: widget.onLongPressPlus,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(8),
                        bottom: Radius.circular(0),
                      ),
                      border: Border.all(color: white),
                      color: Colors.transparent,
                    ),
                    child: const Icon(Icons.add, color: white),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                width: 40,
                child: InkWell(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(0),
                    bottom: Radius.circular(8),
                  ),
                  onTap: widget.onTapMinus,
                  onLongPress: widget.onLongPressMinus,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(0),
                        bottom: Radius.circular(8),
                      ),
                      border: Border.all(color: white),
                      color: Colors.transparent,
                    ),
                    child: const Icon(Icons.remove, color: white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
