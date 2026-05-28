1. [x] Trong file fu_grading/subjectconfig.json này đang chứa các mã môn và % cột điểm của từng môn, khi chạy web cho phép open thêm file này (người dùng tự mở chung với file fg hoặc excel, tức là cùng lúc mở file fg/excel cùng với file subjectconfig này, có thể không bắt buột phải mở file subjectconfig)
2. [x] Khi chạy file config thì hệ thống sẽ so sánh tên cột điểm trong file json và tên cột hiện có để hiện cảnh báo
   - Nếu cột điểm có "type": "on-going" thì nếu giáo viên để trống sẽ hiện cảnh báo bằng ô màu vàng
   - Nếu cột điểm có "type": "practical exam" hay "type": "final exam" thì nếu giáo viên nhập hoặc thay đổi sẽ cảnh báo ô màu đỏ
   - Các cột khác thì để bình thường không có màu
3. [x] Trên mỗi header của cột điểm như (Assignment, Group Project, ...) cho phép nhấn vào, khi nhấn sẽ hiện chi tiết thông tin cột (ví dụ: Name: Assignment, Type: on-going, Weight: 0.10, Completion Criteria: >0)
4. [x] Ở cuối mỗi bảng thì sẽ có một cột Total tính dựa trên Weight của các cột, tối đa 10 tương đương weight = 1, cột này chỉ hiện giá trị tính ra từ các cột khác, không thể sửa giá trị
5. [x] Cho phép thêm/delete các cột điểm vào bảng (Add grading component)
6. [] Cho phép tích chọn các cột để xuất file ra excel hoặc fg, mặc định chọn hết tất cả, có option chọn hết hoặc bỏ chọn hết
7. [x] Thêm chú thích màu sắc (ví dụ: vàng = on-going, đỏ = fe/pe )