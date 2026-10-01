; ModuleID = 'ir_corpus.c'
source_filename = "ir_corpus.c"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "aarch64-unknown-linux-gnu"

@switch.table.sw = private unnamed_addr constant [3 x i32] [i32 1, i32 2, i32 4], align 4

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable
define dso_local i32 @dot(ptr noundef readonly captures(none) %0, ptr noundef readonly captures(none) %1, i32 noundef %2) local_unnamed_addr #0 {
  %4 = icmp sgt i32 %2, 0
  br i1 %4, label %5, label %35

5:                                                ; preds = %3
  %6 = zext nneg i32 %2 to i64
  %7 = icmp ult i32 %2, 8
  br i1 %7, label %32, label %8

8:                                                ; preds = %5
  %9 = and i64 %6, 2147483640
  br label %10

10:                                               ; preds = %10, %8
  %11 = phi i64 [ 0, %8 ], [ %26, %10 ]
  %12 = phi <4 x i32> [ zeroinitializer, %8 ], [ %24, %10 ]
  %13 = phi <4 x i32> [ zeroinitializer, %8 ], [ %25, %10 ]
  %14 = getelementptr inbounds nuw i32, ptr %0, i64 %11
  %15 = getelementptr inbounds nuw i8, ptr %14, i64 16
  %16 = load <4 x i32>, ptr %14, align 4, !tbaa !6
  %17 = load <4 x i32>, ptr %15, align 4, !tbaa !6
  %18 = getelementptr inbounds nuw i32, ptr %1, i64 %11
  %19 = getelementptr inbounds nuw i8, ptr %18, i64 16
  %20 = load <4 x i32>, ptr %18, align 4, !tbaa !6
  %21 = load <4 x i32>, ptr %19, align 4, !tbaa !6
  %22 = mul nsw <4 x i32> %20, %16
  %23 = mul nsw <4 x i32> %21, %17
  %24 = add <4 x i32> %22, %12
  %25 = add <4 x i32> %23, %13
  %26 = add nuw i64 %11, 8
  %27 = icmp eq i64 %26, %9
  br i1 %27, label %28, label %10, !llvm.loop !10

28:                                               ; preds = %10
  %29 = add <4 x i32> %25, %24
  %30 = tail call i32 @llvm.vector.reduce.add.v4i32(<4 x i32> %29)
  %31 = icmp eq i64 %9, %6
  br i1 %31, label %35, label %32

32:                                               ; preds = %5, %28
  %33 = phi i64 [ 0, %5 ], [ %9, %28 ]
  %34 = phi i32 [ 0, %5 ], [ %30, %28 ]
  br label %37

35:                                               ; preds = %37, %28, %3
  %36 = phi i32 [ 0, %3 ], [ %30, %28 ], [ %45, %37 ]
  ret i32 %36

37:                                               ; preds = %32, %37
  %38 = phi i64 [ %46, %37 ], [ %33, %32 ]
  %39 = phi i32 [ %45, %37 ], [ %34, %32 ]
  %40 = getelementptr inbounds nuw i32, ptr %0, i64 %38
  %41 = load i32, ptr %40, align 4, !tbaa !6
  %42 = getelementptr inbounds nuw i32, ptr %1, i64 %38
  %43 = load i32, ptr %42, align 4, !tbaa !6
  %44 = mul nsw i32 %43, %41
  %45 = add nsw i32 %44, %39
  %46 = add nuw nsw i64 %38, 1
  %47 = icmp eq i64 %46, %6
  br i1 %47, label %35, label %37, !llvm.loop !14
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef i32 @max3(i32 noundef %0, i32 noundef %1, i32 noundef %2) local_unnamed_addr #1 {
  %4 = tail call i32 @llvm.smax.i32(i32 %1, i32 %0)
  %5 = tail call i32 @llvm.smax.i32(i32 %2, i32 %4)
  ret i32 %5
}

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable
define dso_local i64 @sumld(ptr noundef readonly captures(none) %0, i64 noundef %1) local_unnamed_addr #0 {
  %3 = icmp sgt i64 %1, 0
  br i1 %3, label %4, label %27

4:                                                ; preds = %2
  %5 = icmp ult i64 %1, 4
  br i1 %5, label %24, label %6

6:                                                ; preds = %4
  %7 = and i64 %1, 9223372036854775804
  br label %8

8:                                                ; preds = %8, %6
  %9 = phi i64 [ 0, %6 ], [ %18, %8 ]
  %10 = phi <2 x i64> [ zeroinitializer, %6 ], [ %16, %8 ]
  %11 = phi <2 x i64> [ zeroinitializer, %6 ], [ %17, %8 ]
  %12 = getelementptr inbounds nuw i64, ptr %0, i64 %9
  %13 = getelementptr inbounds nuw i8, ptr %12, i64 16
  %14 = load <2 x i64>, ptr %12, align 8, !tbaa !15
  %15 = load <2 x i64>, ptr %13, align 8, !tbaa !15
  %16 = add <2 x i64> %14, %10
  %17 = add <2 x i64> %15, %11
  %18 = add nuw i64 %9, 4
  %19 = icmp eq i64 %18, %7
  br i1 %19, label %20, label %8, !llvm.loop !17

20:                                               ; preds = %8
  %21 = add <2 x i64> %17, %16
  %22 = tail call i64 @llvm.vector.reduce.add.v2i64(<2 x i64> %21)
  %23 = icmp eq i64 %1, %7
  br i1 %23, label %27, label %24

24:                                               ; preds = %4, %20
  %25 = phi i64 [ 0, %4 ], [ %7, %20 ]
  %26 = phi i64 [ 0, %4 ], [ %22, %20 ]
  br label %29

27:                                               ; preds = %29, %20, %2
  %28 = phi i64 [ 0, %2 ], [ %22, %20 ], [ %34, %29 ]
  ret i64 %28

29:                                               ; preds = %24, %29
  %30 = phi i64 [ %35, %29 ], [ %25, %24 ]
  %31 = phi i64 [ %34, %29 ], [ %26, %24 ]
  %32 = getelementptr inbounds nuw i64, ptr %0, i64 %30
  %33 = load i64, ptr %32, align 8, !tbaa !15
  %34 = add nsw i64 %33, %31
  %35 = add nuw nsw i64 %30, 1
  %36 = icmp eq i64 %35, %1
  br i1 %36, label %27, label %29, !llvm.loop !18
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i32 0, 5) i32 @sw(i32 noundef %0) local_unnamed_addr #1 {
  %2 = icmp ult i32 %0, 3
  br i1 %2, label %3, label %7

3:                                                ; preds = %1
  %4 = zext nneg i32 %0 to i64
  %5 = getelementptr inbounds nuw [3 x i32], ptr @switch.table.sw, i64 0, i64 %4
  %6 = load i32, ptr %5, align 4
  br label %7

7:                                                ; preds = %1, %3
  %8 = phi i32 [ %6, %3 ], [ 0, %1 ]
  ret i32 %8
}

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable
define dso_local i32 @cnt(ptr noundef readonly captures(none) %0, i32 noundef %1, i32 noundef %2) local_unnamed_addr #0 {
  %4 = icmp eq i32 %1, 0
  br i1 %4, label %35, label %5

5:                                                ; preds = %3
  %6 = zext i32 %1 to i64
  %7 = icmp ult i32 %1, 8
  br i1 %7, label %32, label %8

8:                                                ; preds = %5
  %9 = and i64 %6, 4294967288
  %10 = insertelement <4 x i32> poison, i32 %2, i64 0
  %11 = shufflevector <4 x i32> %10, <4 x i32> poison, <4 x i32> zeroinitializer
  br label %12

12:                                               ; preds = %12, %8
  %13 = phi i64 [ 0, %8 ], [ %26, %12 ]
  %14 = phi <4 x i32> [ zeroinitializer, %8 ], [ %24, %12 ]
  %15 = phi <4 x i32> [ zeroinitializer, %8 ], [ %25, %12 ]
  %16 = getelementptr inbounds nuw i32, ptr %0, i64 %13
  %17 = getelementptr inbounds nuw i8, ptr %16, i64 16
  %18 = load <4 x i32>, ptr %16, align 4, !tbaa !6
  %19 = load <4 x i32>, ptr %17, align 4, !tbaa !6
  %20 = icmp eq <4 x i32> %18, %11
  %21 = icmp eq <4 x i32> %19, %11
  %22 = zext <4 x i1> %20 to <4 x i32>
  %23 = zext <4 x i1> %21 to <4 x i32>
  %24 = add <4 x i32> %14, %22
  %25 = add <4 x i32> %15, %23
  %26 = add nuw i64 %13, 8
  %27 = icmp eq i64 %26, %9
  br i1 %27, label %28, label %12, !llvm.loop !19

28:                                               ; preds = %12
  %29 = add <4 x i32> %25, %24
  %30 = tail call i32 @llvm.vector.reduce.add.v4i32(<4 x i32> %29)
  %31 = icmp eq i64 %9, %6
  br i1 %31, label %35, label %32

32:                                               ; preds = %5, %28
  %33 = phi i64 [ 0, %5 ], [ %9, %28 ]
  %34 = phi i32 [ 0, %5 ], [ %30, %28 ]
  br label %37

35:                                               ; preds = %37, %28, %3
  %36 = phi i32 [ 0, %3 ], [ %30, %28 ], [ %44, %37 ]
  ret i32 %36

37:                                               ; preds = %32, %37
  %38 = phi i64 [ %45, %37 ], [ %33, %32 ]
  %39 = phi i32 [ %44, %37 ], [ %34, %32 ]
  %40 = getelementptr inbounds nuw i32, ptr %0, i64 %38
  %41 = load i32, ptr %40, align 4, !tbaa !6
  %42 = icmp eq i32 %41, %2
  %43 = zext i1 %42 to i32
  %44 = add i32 %39, %43
  %45 = add nuw nsw i64 %38, 1
  %46 = icmp eq i64 %45, %6
  br i1 %46, label %35, label %37, !llvm.loop !20
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef i32 @sat(i32 noundef %0, i32 noundef %1, i32 noundef %2) local_unnamed_addr #1 {
  %4 = icmp slt i32 %0, %1
  %5 = tail call i32 @llvm.smin.i32(i32 %0, i32 %2)
  %6 = select i1 %4, i32 %1, i32 %5
  ret i32 %6
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local i64 @mix(i64 noundef %0, i64 noundef %1, i64 noundef %2) local_unnamed_addr #1 {
  %4 = mul nsw i64 %1, %0
  %5 = mul nsw i64 %2, 3
  %6 = xor i64 %1, %0
  %7 = add i64 %6, %4
  %8 = add i64 %7, %5
  %9 = shl i64 %2, 1
  %10 = sub i64 %8, %9
  ret i64 %10
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i32 0, -2147483648) i32 @cond(i32 noundef %0, i32 noundef %1) local_unnamed_addr #1 {
  %3 = sub nsw i32 %0, %1
  %4 = tail call i32 @llvm.abs.i32(i32 %3, i1 true)
  ret i32 %4
}

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: read) uwtable
define dso_local i64 @walk(ptr noundef readonly captures(none) %0, i64 noundef %1) local_unnamed_addr #0 {
  %3 = icmp sgt i64 %1, 0
  br i1 %3, label %4, label %33

4:                                                ; preds = %2
  %5 = icmp eq i64 %1, 1
  br i1 %5, label %30, label %6

6:                                                ; preds = %4
  %7 = and i64 %1, 9223372036854775806
  %8 = getelementptr i8, ptr %0, i64 8
  br label %9

9:                                                ; preds = %9, %6
  %10 = phi i64 [ 0, %6 ], [ %25, %9 ]
  %11 = phi i64 [ 0, %6 ], [ %23, %9 ]
  %12 = phi i64 [ 0, %6 ], [ %24, %9 ]
  %13 = getelementptr inbounds nuw i64, ptr %0, i64 %10
  %14 = getelementptr i64, ptr %8, i64 %10
  %15 = load i64, ptr %13, align 8, !tbaa !15
  %16 = load i64, ptr %14, align 8, !tbaa !15
  %17 = mul nsw i64 %15, 3
  %18 = mul nsw i64 %16, 3
  %19 = ashr i64 %15, 2
  %20 = ashr i64 %16, 2
  %21 = add i64 %19, %11
  %22 = add i64 %20, %12
  %23 = add i64 %21, %17
  %24 = add i64 %22, %18
  %25 = add nuw i64 %10, 2
  %26 = icmp eq i64 %25, %7
  br i1 %26, label %27, label %9, !llvm.loop !21

27:                                               ; preds = %9
  %28 = add i64 %24, %23
  %29 = icmp eq i64 %1, %7
  br i1 %29, label %33, label %30

30:                                               ; preds = %4, %27
  %31 = phi i64 [ 0, %4 ], [ %7, %27 ]
  %32 = phi i64 [ 0, %4 ], [ %28, %27 ]
  br label %35

33:                                               ; preds = %35, %27, %2
  %34 = phi i64 [ 0, %2 ], [ %28, %27 ], [ %43, %35 ]
  ret i64 %34

35:                                               ; preds = %30, %35
  %36 = phi i64 [ %44, %35 ], [ %31, %30 ]
  %37 = phi i64 [ %43, %35 ], [ %32, %30 ]
  %38 = getelementptr inbounds nuw i64, ptr %0, i64 %36
  %39 = load i64, ptr %38, align 8, !tbaa !15
  %40 = mul nsw i64 %39, 3
  %41 = ashr i64 %39, 2
  %42 = add i64 %41, %37
  %43 = add i64 %42, %40
  %44 = add nuw nsw i64 %36, 1
  %45 = icmp eq i64 %44, %1
  br i1 %45, label %33, label %35, !llvm.loop !22
}

; Function Attrs: nofree norecurse nosync nounwind memory(none) uwtable
define dso_local i32 @popcntish(i32 noundef %0) local_unnamed_addr #2 {
  %2 = icmp eq i32 %0, 0
  br i1 %2, label %10, label %3

3:                                                ; preds = %1, %3
  %4 = phi i32 [ %7, %3 ], [ 0, %1 ]
  %5 = phi i32 [ %8, %3 ], [ %0, %1 ]
  %6 = and i32 %5, 1
  %7 = add i32 %4, %6
  %8 = lshr i32 %5, 1
  %9 = icmp ult i32 %5, 2
  br i1 %9, label %10, label %3, !llvm.loop !23

10:                                               ; preds = %3, %1
  %11 = phi i32 [ 0, %1 ], [ %7, %3 ]
  ret i32 %11
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local i32 @mul3(i32 noundef %0) local_unnamed_addr #1 {
  %2 = mul nsw i32 %0, 3
  ret i32 %2
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.smin.i32(i32, i32) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.smax.i32(i32, i32) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.abs.i32(i32, i1 immarg) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.vector.reduce.add.v4i32(<4 x i32>) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.vector.reduce.add.v2i64(<2 x i64>) #3

attributes #0 = { nofree norecurse nosync nounwind memory(argmem: read) uwtable "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic" "target-features"="+fp-armv8,+neon,+v8a,-fmv" }
attributes #1 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic" "target-features"="+fp-armv8,+neon,+v8a,-fmv" }
attributes #2 = { nofree norecurse nosync nounwind memory(none) uwtable "frame-pointer"="non-leaf" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic" "target-features"="+fp-armv8,+neon,+v8a,-fmv" }
attributes #3 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.module.flags = !{!0, !1, !2, !3, !4}
!llvm.ident = !{!5}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{i32 7, !"frame-pointer", i32 1}
!5 = !{!"Ubuntu clang version 21.1.8 (6ubuntu1)"}
!6 = !{!7, !7, i64 0}
!7 = !{!"int", !8, i64 0}
!8 = !{!"omnipotent char", !9, i64 0}
!9 = !{!"Simple C/C++ TBAA"}
!10 = distinct !{!10, !11, !12, !13}
!11 = !{!"llvm.loop.mustprogress"}
!12 = !{!"llvm.loop.isvectorized", i32 1}
!13 = !{!"llvm.loop.unroll.runtime.disable"}
!14 = distinct !{!14, !11, !13, !12}
!15 = !{!16, !16, i64 0}
!16 = !{!"long", !8, i64 0}
!17 = distinct !{!17, !11, !12, !13}
!18 = distinct !{!18, !11, !13, !12}
!19 = distinct !{!19, !11, !12, !13}
!20 = distinct !{!20, !11, !13, !12}
!21 = distinct !{!21, !11, !12, !13}
!22 = distinct !{!22, !11, !12}
!23 = distinct !{!23, !11}
