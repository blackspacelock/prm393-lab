using System;
using System.IO;
using System.Collections.Generic;
using System.Runtime.Serialization.Formatters.Binary;
using System.Runtime.Serialization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace FuGradeLib
{
    [Serializable]
    public class TeacherGrade
    {
        public string Version;
        public string Semester;
        public string Login;
        public string Password;
        public List<SubjectClassGrade> SubjectClassGrades;
    }

    [Serializable]
    public class SubjectClassGrade
    {
        public string Subject;
        public string Class;
        public List<Student> Students;
        public List<string> Components;
    }

    [Serializable]
    public class Student
    {
        public string Roll { get; set; }
        public string Name { get; set; }
        public List<GradeComponent> Grades { get; set; }
        public string Comment { get; set; }
    }

    [Serializable]
    public class GradeComponent
    {
        public string Component { get; set; }
        public float? Grade { get; set; }
    }
}

class CustomBinder : SerializationBinder
{
    public override Type BindToType(string assemblyName, string typeName)
    {
        if (typeName.Contains("TeacherGrade")) return typeof(FuGradeLib.TeacherGrade);

        if (typeName.Contains("List`1[[FuGradeLib.SubjectClassGrade")) return typeof(List<FuGradeLib.SubjectClassGrade>);
        if (typeName.Contains("SubjectClassGrade[]")) return typeof(FuGradeLib.SubjectClassGrade[]);
        if (typeName.Contains("SubjectClassGrade")) return typeof(FuGradeLib.SubjectClassGrade);

        if (typeName.Contains("List`1[[FuGradeLib.Student")) return typeof(List<FuGradeLib.Student>);
        if (typeName.Contains("Student[]")) return typeof(FuGradeLib.Student[]);
        if (typeName.Contains("Student")) return typeof(FuGradeLib.Student);

        if (typeName.Contains("List`1[[FuGradeLib.GradeComponent")) return typeof(List<FuGradeLib.GradeComponent>);
        if (typeName.Contains("GradeComponent[]")) return typeof(FuGradeLib.GradeComponent[]);
        if (typeName.Contains("GradeComponent")) return typeof(FuGradeLib.GradeComponent);

        return null;
    }
}

class Program
{
    static void Main(string[] args)
    {
        string filePath = args.Length > 0 && !string.IsNullOrWhiteSpace(args[0])
            ? args[0]
            : @"D:\6_repositories\prm393-lab\lab-1-fu-grading-with-flutter\subject-1\phuonglhkSpring2024.fg";

        if (!File.Exists(filePath))
        {
            Console.WriteLine("File not found.");
            return;
        }

#pragma warning disable SYSLIB0011
        BinaryFormatter formatter = new BinaryFormatter();
        formatter.Binder = new CustomBinder();
        FuGradeLib.TeacherGrade data;

        using (FileStream fs = new FileStream(filePath, FileMode.Open))
        {
            data = (FuGradeLib.TeacherGrade)formatter.Deserialize(fs);
        }
#pragma warning restore SYSLIB0011

        var payload = new
        {
            version = data.Version,
            semester = data.Semester,
            login = data.Login,
            password = data.Password,
            components = GetAllComponents(data.SubjectClassGrades),
            classes = BuildClasses(data.SubjectClassGrades),
        };

        var jsonOptions = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        };

        Console.WriteLine(JsonSerializer.Serialize(payload, jsonOptions));
    }

    private static List<string> GetAllComponents(List<FuGradeLib.SubjectClassGrade> subjectClassGrades)
    {
        var components = new List<string>();

        foreach (var subjectClass in subjectClassGrades)
        {
            if (subjectClass.Components == null)
            {
                continue;
            }

            foreach (var component in subjectClass.Components)
            {
                if (!string.IsNullOrWhiteSpace(component) && !components.Contains(component))
                {
                    components.Add(component);
                }
            }
        }

        return components;
    }

    private static List<object> BuildClasses(List<FuGradeLib.SubjectClassGrade> subjectClassGrades)
    {
        var classes = new List<object>();

        foreach (var subjectClass in subjectClassGrades)
        {
            var students = new List<object>();

            if (subjectClass.Students != null)
            {
                foreach (var student in subjectClass.Students)
                {
                    var grades = new List<object>();

                    if (student.Grades != null)
                    {
                        foreach (var grade in student.Grades)
                        {
                            grades.Add(new
                            {
                                component = grade.Component,
                                grade = grade.Grade,
                            });
                        }
                    }

                    students.Add(new
                    {
                        roll = student.Roll,
                        name = student.Name,
                        comment = student.Comment,
                        grades,
                    });
                }
            }

            classes.Add(new
            {
                subject = subjectClass.Subject,
                classCode = subjectClass.Class,
                components = subjectClass.Components ?? new List<string>(),
                students,
            });
        }

        return classes;
    }
}